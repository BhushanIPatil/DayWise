import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'record_view_options.dart';
import 'record_search.dart';
import '../state/app_state.dart';
import 'day_page.dart';
import 'widgets.dart';
import 'report_export.dart';
import 'accounts_page.dart';
import 'chart_value_bar.dart';
import 'category_analysis.dart';

/// Income and expense bars for each day of the week.
class WeekPage extends StatefulWidget {
  const WeekPage({super.key, this.onCalendarView});
  final VoidCallback? onCalendarView;

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  DateTime _anchor = dateOnly(DateTime.now());
  AnalysisView _analysisView = AnalysisView.overview;
  final _view = RecordViewOptions();
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
    final start = startOfWeek(_anchor, s.weekStart);
    final end = addDays(start, 6);
    final days = [for (var i = 0; i < 7; i++) addDays(start, i)];
    final per = [for (final d in days) _view.filterTotals(s.dayTotals(d))];
    final total = _view.filterTotals(s.rangeTotals(start, end));
    final prev = _view.filterTotals(
      s.rangeTotals(addDays(start, -7), addDays(start, -1)),
    );
    final maximum = per.fold<BigInt>(
      BigInt.zero,
      (m, t) => [m, t.income, t.expense].reduce((a, b) => a > b ? a : b),
    );
    final today = dateOnly(DateTime.now());

    String? deltaText;
    Color deltaColor = context.cs.onSurfaceVariant;
    if (prev.expense > BigInt.zero) {
      final difference = total.expense - prev.expense;
      final pct =
          (difference.abs() * BigInt.from(100) + prev.expense ~/ BigInt.two) ~/
          prev.expense;
      deltaText = '${difference >= BigInt.zero ? '▲' : '▼'} $pct% vs last week';
      deltaColor = difference > BigInt.zero ? Brand.expense : Brand.income;
    } else if (total.expense > BigInt.zero) {
      deltaText = 'Nothing spent last week';
    }

    final title =
        '${fmtShort(start)}${start.year == end.year ? '' : ' ${start.year}'} – ${fmtShort(end)} ${end.year}';

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
              includeAccounts: true,
              title: 'Week',
              entries: _view.apply(s.recordsInRange(start, end)),
              from: start,
              to: end,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: PeriodNavigator(
                  title: title,
                  onPrev: () => setState(() => _anchor = addDays(_anchor, -7)),
                  onNext: () => setState(() => _anchor = addDays(_anchor, 7)),
                ),
              ),
              IconButton(
                tooltip: 'Switch to calendar',
                onPressed: widget.onCalendarView,
                icon: const Icon(Icons.calendar_month_rounded),
              ),
              RecordSortButton(
                options: _view,
                showDateSort: false,
                onChanged: () => setState(() {}),
              ),
            ],
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
          AnalysisViewToggle(
            value: _analysisView,
            onChanged: (view) => setState(() => _analysisView = view),
          ),
          Expanded(
            child: _query.trim().isNotEmpty
                ? RecordSearchResults(query: _query, options: _view)
                : _analysisView == AnalysisView.categories
                ? CategoryAnalysis(
                    entries: _view.apply(s.recordsInRange(start, end)),
                    type: _view.type,
                    from: start,
                    to: end,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _view.type == TxType.income
                                  ? 'Income this week'
                                  : 'Spent this week',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                money.full(
                                  _view.type == TxType.income
                                      ? total.income
                                      : total.expense,
                                ),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            if (deltaText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  deltaText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: deltaColor,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                if (_view.type == null)
                                  StatChip(
                                    label: 'Income',
                                    value: money.full(total.income),
                                    color: Brand.income,
                                  ),
                                if (_view.type == null)
                                  const SizedBox(width: 8),
                                StatChip(
                                  label: 'Daily average',
                                  value: money.full(
                                    (_view.type == TxType.income
                                            ? total.income
                                            : total.expense) ~/
                                        BigInt.from(7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              children: [
                                if (total.income > BigInt.zero)
                                  const Text(
                                    'Income',
                                    style: TextStyle(
                                      color: Brand.income,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (total.expense > BigInt.zero)
                                  const Text(
                                    'Expense',
                                    style: TextStyle(
                                      color: Brand.expense,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: math.max(
                                        constraints.maxWidth,
                                        7 *
                                            (total.income > BigInt.zero &&
                                                    total.expense > BigInt.zero
                                                ? 88.0
                                                : 48.0),
                                      ),
                                      height:
                                          138 +
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(34),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          for (var i = 0; i < 7; i++)
                                            Expanded(
                                              child: _Bar(
                                                date: days[i],
                                                income: per[i].income,
                                                expense: per[i].expense,
                                                maximum: maximum,
                                                money: money,
                                                isToday: sameDay(
                                                  days[i],
                                                  today,
                                                ),
                                                onTap: () => showDayPage(
                                                  context,
                                                  days[i],
                                                  options: _view,
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
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < 7; i++)
                              InkWell(
                                borderRadius: BorderRadius.circular(
                                  Brand.controlRadius,
                                ),
                                onTap: () => showDayPage(
                                  context,
                                  days[i],
                                  options: _view,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 64,
                                        child: Text(
                                          '${fmtWeekday(days[i]).substring(0, 3)} ${days[i].day}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: sameDay(days[i], today)
                                                ? context.cs.primary
                                                : null,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          per[i].income > BigInt.zero
                                              ? '+${money.full(per[i].income)}'
                                              : '',
                                          style: const TextStyle(
                                            color: Brand.income,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      if (_view.type != TxType.income)
                                        Text(
                                          per[i].expense > BigInt.zero
                                              ? money.full(per[i].expense)
                                              : '—',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: per[i].expense > BigInt.zero
                                                ? Brand.expense
                                                : context.cs.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.date,
    required this.income,
    required this.expense,
    required this.maximum,
    required this.money,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final BigInt income;
  final BigInt expense;
  final BigInt maximum;
  final MoneyFormat money;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('week-day-${dateKey(date)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (income > BigInt.zero)
                    Expanded(
                      child: ChartValueBar(
                        value: income,
                        maximum: maximum,
                        money: money,
                        color: Brand.income,
                        description: '${fmtShort(date)} Income',
                      ),
                    ),
                  if (income > BigInt.zero && expense > BigInt.zero)
                    const SizedBox(width: 4),
                  if (expense > BigInt.zero)
                    Expanded(
                      child: ChartValueBar(
                        value: expense,
                        maximum: maximum,
                        money: money,
                        color: Brand.expense,
                        description: '${fmtShort(date)} Expense',
                      ),
                    ),
                  if (income == BigInt.zero && expense == BigInt.zero)
                    Expanded(
                      child: ChartValueBar(
                        value: BigInt.zero,
                        maximum: maximum,
                        money: money,
                        color: context.softFill,
                        description: '${fmtShort(date)} No records',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fmtWeekday(date).substring(0, 3),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? context.cs.primary
                    : context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
