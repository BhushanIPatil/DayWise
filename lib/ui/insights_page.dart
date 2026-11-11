import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'day_sheet.dart';
import 'widgets.dart';
import 'report_export.dart';

/// Month insights: day-by-day bars, headline stats and category breakdown.
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final y = _month.year;
    final m = _month.month;
    final n = DateTime(y, m + 1, 0).day;
    final first = DateTime(y, m, 1);
    final last = DateTime(y, m, n);
    final now = dateOnly(DateTime.now());
    final totals = s.monthTotals(y, m);

    final daily = [
      for (var d = 1; d <= n; d++) s.dayTotals(DateTime(y, m, d)).expense,
    ];
    final maxDay = daily.fold<int>(0, math.max);
    final maxIndex = maxDay == 0 ? -1 : daily.indexOf(maxDay);

    int elapsed;
    if (last.isBefore(now)) {
      elapsed = n;
    } else if (first.isAfter(now)) {
      elapsed = 0;
    } else {
      elapsed = now.day;
    }
    final avg = elapsed == 0 ? 0 : totals.expense ~/ elapsed;
    var noSpend = 0;
    for (var d = 0; d < elapsed; d++) {
      if (daily[d] == 0) noSpend++;
    }
    var count = 0;
    for (var d = 1; d <= n; d++) {
      count += s.forDay(DateTime(y, m, d)).length;
    }
    final cats = s.expenseByCategory(first, last);
    final catTotal = cats.fold<int>(0, (a, e) => a + e.value);
    final budget = s.monthlyBudgetMinor;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: PeriodNavigator(
                  title: fmtMonth(_month),
                  subtitle: '$y',
                  onPrev: () => setState(() => _month = DateTime(y, m - 1)),
                  onNext: () => setState(() => _month = DateTime(y, m + 1)),
                ),
              ),
              ReportExport(
                title: 'Insights ${fmtMonth(_month)} $y',
                from: first,
                to: last,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (count == 0)
            const GlassCard(
              child: EmptyState(
                icon: Icons.insights_rounded,
                title: 'No entries this month',
                subtitle:
                    'Add expenses from the calendar and your insights will appear here.',
              ),
            )
          else ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      StatChip(
                        label: 'Spent',
                        value: money.full(totals.expense),
                        color: Brand.expense,
                      ),
                      const SizedBox(width: 8),
                      StatChip(
                        label: 'Income',
                        value: money.full(totals.income),
                        color: Brand.income,
                      ),
                      const SizedBox(width: 8),
                      StatChip(label: 'Saved', value: money.signed(totals.net)),
                    ],
                  ),
                  if (budget > 0) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: math.min(1.0, totals.expense / budget),
                        minHeight: 8,
                        backgroundColor: context.softFill,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          totals.expense > budget
                              ? Brand.expense
                              : context.cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        totals.expense > budget
                            ? 'Over the ${money.full(budget)} budget by ${money.full(totals.expense - budget)}'
                            : '${(totals.expense * 100 / budget).round()}% of ${money.full(budget)} budget used',
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
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Day by day',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var d = 1; d <= n; d++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  showDaySheet(context, DateTime(y, m, d)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: daily[d - 1] == 0
                                        ? 3
                                        : math.max(
                                            5.0,
                                            130 * daily[d - 1] / maxDay,
                                          ),
                                    decoration: BoxDecoration(
                                      color: daily[d - 1] == 0
                                          ? context.softFill
                                          : (d - 1 == maxIndex
                                                ? Brand.expense
                                                : context.cs.primary),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final label in ['1', '${(n / 2).ceil()}', '$n'])
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statTile(
                  context,
                  Icons.local_fire_department_rounded,
                  'Highest day',
                  maxDay == 0 ? '—' : money.full(maxDay),
                  maxDay == 0
                      ? ''
                      : '${maxIndex + 1} ${fmtMonth(_month).substring(0, 3)}',
                  Brand.expense,
                ),
                const SizedBox(width: 10),
                _statTile(
                  context,
                  Icons.speed_rounded,
                  'Daily average',
                  money.full(avg),
                  'so far this month',
                  context.cs.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statTile(
                  context,
                  Icons.celebration_rounded,
                  'No-spend days',
                  '$noSpend',
                  'of $elapsed days',
                  Brand.income,
                ),
                const SizedBox(width: 10),
                _statTile(
                  context,
                  Icons.receipt_long_rounded,
                  'Entries',
                  '$count',
                  'this month',
                  const Color(0xFFFD9644),
                ),
              ],
            ),
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Where it went',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            for (final e in cats)
                              Expanded(
                                flex: math.max(1, e.value),
                                child: Container(
                                  color: s.categoryById(e.key).colorValue,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final e in cats)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CategoryBubble(
                              category: s.categoryById(e.key),
                              size: 38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.categoryById(e.key).name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: catTotal == 0
                                          ? 0
                                          : e.value / catTotal,
                                      minHeight: 5,
                                      backgroundColor: context.softFill,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        s.categoryById(e.key).colorValue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money.full(e.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${(e.value * 100 / catTotal).round()}%',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    String sub,
    Color color,
  ) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint(color, 0.15),
                borderRadius: BorderRadius.circular(11),
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
