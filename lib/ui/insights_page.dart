import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'day_page.dart';
import 'widgets.dart';
import 'accounts_page.dart';
import 'report_period.dart';
import 'record_search.dart';
import 'report_export.dart';
import 'record_view_options.dart';
import 'chart_value_bar.dart';

/// Period insights: day-by-day bars and headline stats.
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final _period = ReportPeriod();
  final _view = RecordViewOptions()..ascending = true;
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final range = _period.range(s.weekStart);
    final source = s.recordsInRange(range?.start, range?.end);
    final entries = _view.apply(source);
    final incomeOnly = _view.type == TxType.income;
    final now = dateOnly(DateTime.now());
    final first =
        range?.start ?? (source.isEmpty ? now : dateOnly(source.last.date));
    final last =
        range?.end ?? (source.isEmpty ? now : dateOnly(source.first.date));
    final n = last.difference(first).inDays + 1;
    final totals = Totals(
      entries
          .where((txn) => txn.isIncome)
          .fold<BigInt>(BigInt.zero, (sum, txn) => sum + txn.amountMinor),
      entries
          .where((txn) => !txn.isIncome)
          .fold<BigInt>(BigInt.zero, (sum, txn) => sum + txn.amountMinor),
    );
    final perDay = <String, Totals>{};
    for (final txn in entries) {
      final key = dateKey(txn.date);
      perDay[key] =
          (perDay[key] ?? Totals.zero) +
          (txn.isIncome
              ? Totals(txn.amountMinor, 0)
              : Totals(0, txn.amountMinor));
    }
    final dailyTotals = [
      for (var d = 0; d < n; d++)
        perDay[dateKey(addDays(first, d))] ?? Totals.zero,
    ];
    final days = [for (var d = 1; d <= n; d++) d];
    final chartDays = _view.ascending ? days : days.reversed.toList();
    final chartMaximum = dailyTotals.fold<BigInt>(
      BigInt.zero,
      (maximum, total) => [
        maximum,
        total.income,
        total.expense,
      ].reduce((a, b) => a > b ? a : b),
    );

    int elapsed;
    if (last.isBefore(now)) {
      elapsed = n;
    } else if (first.isAfter(now)) {
      elapsed = 0;
    } else {
      elapsed = now.difference(first).inDays + 1;
    }
    final count = entries.length;
    final budget =
        !incomeOnly &&
            (_period.filter == null || _period.filter == DateFilter.month)
        ? s.monthlyBudgetMinor
        : 0;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          AccountSwitcher(
            viewToggle: IconButton(
              tooltip: 'Search',
              onPressed: () => setState(() => _searching = true),
              icon: const Icon(Icons.search_rounded),
            ),
            actions: ReportExport(
              entries: entries,
              title: 'Insights',
              from: range?.start,
              to: range?.end,
              includeAccounts: true,
            ),
          ),
          ReportPeriodBar(
            period: _period,
            onChanged: () => setState(() {}),
            trailing: RecordSortButton(
              options: _view,
              onChanged: () => setState(() {}),
            ),
          ),
          if (_searching)
            InlineRecordSearch(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              onClose: () {
                FocusScope.of(context).unfocus();
                _searchController.clear();
                setState(() {
                  _searching = false;
                  _query = '';
                });
              },
            ),
          Expanded(
            child: _query.trim().isNotEmpty
                ? RecordSearchResults(
                    query: _query,
                    from: range?.start,
                    to: range?.end,
                    options: _view,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (count == 0)
                        const GlassCard(
                          child: EmptyState(
                            icon: Icons.insights_rounded,
                            title: 'No entries in this period',
                            subtitle:
                                'Add records from the calendar and your insights will appear here.',
                          ),
                        )
                      else ...[
                        Column(
                          children: [
                            Row(
                              children: [
                                if (_view.type != TxType.income)
                                  StatChip(
                                    label: 'Spent',
                                    value: money.full(totals.expense),
                                    color: Brand.expense,
                                  ),
                                if (_view.type == null)
                                  const SizedBox(width: 8),
                                if (_view.type != TxType.expense)
                                  StatChip(
                                    label: 'Income',
                                    value: money.full(totals.income),
                                    color: Brand.income,
                                  ),
                                if (_view.type == null)
                                  const SizedBox(width: 8),
                                if (_view.type == null)
                                  StatChip(
                                    label: 'Saved',
                                    value: money.signed(totals.net),
                                  ),
                              ],
                            ),
                            if (budget > 0) ...[
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  Brand.controlRadius,
                                ),
                                child: LinearProgressIndicator(
                                  value: minorRatio(totals.expense, budget),
                                  minHeight: 8,
                                  backgroundColor: context.softFill,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    totals.expense > BigInt.from(budget)
                                        ? Brand.expense
                                        : context.cs.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  totals.expense > BigInt.from(budget)
                                      ? 'Over the ${money.full(budget)} budget by ${money.full(totals.expense - BigInt.from(budget))}'
                                      : '${(totals.expense * BigInt.from(100) + BigInt.from(budget) ~/ BigInt.two) ~/ BigInt.from(budget)}% of ${money.full(budget)} budget used',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  incomeOnly
                                      ? 'Income by day'
                                      : _view.type == TxType.expense
                                      ? 'Expense by day'
                                      : 'Income and expense by day',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 16,
                                children: [
                                  if (totals.income > BigInt.zero)
                                    const Text(
                                      'Income',
                                      style: TextStyle(
                                        color: Brand.income,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  if (totals.expense > BigInt.zero)
                                    const Text(
                                      'Expense',
                                      style: TextStyle(
                                        color: Brand.expense,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height:
                                    130 +
                                    MediaQuery.textScalerOf(context).scale(34),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: math.max(
                                      MediaQuery.sizeOf(context).width - 60,
                                      n *
                                          (totals.income > BigInt.zero &&
                                                  totals.expense > BigInt.zero
                                              ? 88.0
                                              : 48.0),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        for (final d in chartDays)
                                          Expanded(
                                            child: GestureDetector(
                                              key: ValueKey(
                                                'insight-day-${dateKey(addDays(first, d - 1))}',
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => showDayPage(
                                                context,
                                                addDays(first, d - 1),
                                                options: _view,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                    ),
                                                child: Column(
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          for (final series in [
                                                            (
                                                              dailyTotals[d - 1]
                                                                  .income,
                                                              Brand.income,
                                                              'Income',
                                                            ),
                                                            (
                                                              dailyTotals[d - 1]
                                                                  .expense,
                                                              Brand.expense,
                                                              'Expense',
                                                            ),
                                                          ])
                                                            if (series.$1 >
                                                                BigInt.zero)
                                                              Expanded(
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            2,
                                                                      ),
                                                                  child: ChartValueBar(
                                                                    value:
                                                                        series
                                                                            .$1,
                                                                    maximum:
                                                                        chartMaximum,
                                                                    money:
                                                                        money,
                                                                    color:
                                                                        series
                                                                            .$2,
                                                                    description:
                                                                        '${fmtShort(addDays(first, d - 1))} ${series.$3}',
                                                                  ),
                                                                ),
                                                              ),
                                                          if (dailyTotals[d - 1]
                                                              .isEmpty)
                                                            Expanded(
                                                              child: ChartValueBar(
                                                                value:
                                                                    BigInt.zero,
                                                                maximum:
                                                                    chartMaximum,
                                                                money: money,
                                                                color: context
                                                                    .softFill,
                                                                description:
                                                                    '${fmtShort(addDays(first, d - 1))} No records',
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        fmtShort(
                                                          addDays(first, d - 1),
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: context
                                                              .cs
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _statistics(
                          context,
                          entries: entries,
                          dailyTotals: dailyTotals,
                          first: first,
                          elapsed: elapsed,
                          money: money,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statistics(
    BuildContext context, {
    required List<Txn> entries,
    required List<Totals> dailyTotals,
    required DateTime first,
    required int elapsed,
    required MoneyFormat money,
  }) {
    final both = _view.type == null;
    List<Widget> tiles(TxType type) {
      final income = type == TxType.income;
      final name = income ? 'Income' : 'Expense';
      final color = income ? Brand.income : Brand.expense;
      final daily = [
        for (final total in dailyTotals) income ? total.income : total.expense,
      ];
      final highest = daily.fold<BigInt>(BigInt.zero, (a, b) => a > b ? a : b);
      final total = daily.fold<BigInt>(BigInt.zero, (a, b) => a + b);
      final average = elapsed == 0
          ? BigInt.zero
          : total ~/ BigInt.from(elapsed);
      final inactive = daily
          .take(elapsed)
          .where((value) => value == BigInt.zero)
          .length;
      final count = entries.where((entry) => entry.type == type).length;
      Widget tile(
        String metric,
        IconData icon,
        String label,
        String value,
        String sub,
      ) => _statTile(
        context,
        icon,
        label,
        value,
        sub,
        color,
        key: ValueKey('insight-stat-${type.name}-$metric'),
      );
      return [
        tile(
          'highest',
          Icons.local_fire_department_rounded,
          both ? 'Highest ${name.toLowerCase()} day' : 'Highest day',
          highest == BigInt.zero ? '—' : money.full(highest),
          highest == BigInt.zero
              ? ''
              : fmtShort(addDays(first, daily.indexOf(highest))),
        ),
        tile(
          'average',
          Icons.speed_rounded,
          both ? '$name daily average' : 'Daily average',
          money.full(average),
          'in this period',
        ),
        tile(
          'inactive',
          Icons.celebration_rounded,
          income ? 'No-income days' : 'No-spend days',
          '$inactive',
          'of $elapsed days',
        ),
        tile(
          'count',
          Icons.receipt_long_rounded,
          both ? '$name entries' : 'Entries',
          '$count',
          'in this period',
        ),
      ];
    }

    final groups = both
        ? [tiles(TxType.income), tiles(TxType.expense)]
        : [tiles(_view.type!)];
    return Column(
      children: [
        for (var row = 0; row < (both ? 4 : 2); row++) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              both ? groups[0][row] : groups[0][row * 2],
              const SizedBox(width: 10),
              both ? groups[1][row] : groups[0][row * 2 + 1],
            ],
          ),
        ],
      ],
    );
  }

  Widget _statTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    String sub,
    Color color, {
    Key? key,
  }) {
    return Expanded(
      child: GlassCard(
        key: key,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint(color, 0.15),
                borderRadius: BorderRadius.circular(Brand.controlRadius),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
