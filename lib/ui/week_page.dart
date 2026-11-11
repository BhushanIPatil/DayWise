import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'day_sheet.dart';
import 'widgets.dart';
import 'report_export.dart';

/// Seven bars: how much was spent on each day of the week.
class WeekPage extends StatefulWidget {
  const WeekPage({super.key});

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  DateTime _anchor = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final start = startOfWeek(_anchor, s.weekStart);
    final end = addDays(start, 6);
    final days = [for (var i = 0; i < 7; i++) addDays(start, i)];
    final per = [for (final d in days) s.dayTotals(d)];
    final total = s.rangeTotals(start, end);
    final prev = s.rangeTotals(addDays(start, -7), addDays(start, -1));
    final maxExp = per.fold<int>(0, (m, t) => math.max(m, t.expense));
    final today = dateOnly(DateTime.now());
    final cats = s.expenseByCategory(start, end);

    String? deltaText;
    Color deltaColor = context.cs.onSurfaceVariant;
    if (prev.expense > 0) {
      final pct = ((total.expense - prev.expense) * 100 / prev.expense).round();
      deltaText = '${pct >= 0 ? '▲' : '▼'} ${pct.abs()}% vs last week';
      deltaColor = pct > 0 ? Brand.expense : Brand.income;
    } else if (total.expense > 0) {
      deltaText = 'Nothing spent last week';
    }

    final sameMonth = start.month == end.month;
    final title = sameMonth
        ? '${start.day} – ${end.day} ${fmtMonth(end).substring(0, 3)}'
        : '${fmtShort(start)} – ${fmtShort(end)}';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: PeriodNavigator(
                  title: title,
                  subtitle: '${end.year}',
                  onPrev: () => setState(() => _anchor = addDays(_anchor, -7)),
                  onNext: () => setState(() => _anchor = addDays(_anchor, 7)),
                ),
              ),
              ReportExport(
                title: 'Week ${dateKey(start)} to ${dateKey(end)}',
                from: start,
                to: end,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spent this week',
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
                    money.full(total.expense),
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
                    StatChip(
                      label: 'Income',
                      value: money.full(total.income),
                      color: Brand.income,
                    ),
                    const SizedBox(width: 8),
                    StatChip(
                      label: 'Daily average',
                      value: money.full(total.expense ~/ 7),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
            child: SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _Bar(
                        label: fmtWeekday(days[i]).substring(0, 3),
                        value: per[i].expense,
                        ratio: maxExp == 0 ? 0 : per[i].expense / maxExp,
                        valueLabel: per[i].expense == 0
                            ? ''
                            : money.compact(per[i].expense),
                        isToday: sameDay(days[i], today),
                        overBudget:
                            s.dailyBudgetMinor > 0 &&
                            per[i].expense > s.dailyBudgetMinor,
                        onTap: () => showDaySheet(context, days[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (var i = 0; i < 7; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showDaySheet(context, days[i]),
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
                              per[i].income > 0
                                  ? '+${money.full(per[i].income)}'
                                  : '',
                              style: const TextStyle(
                                color: Brand.income,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          Text(
                            per[i].expense > 0
                                ? money.full(per[i].expense)
                                : '—',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: per[i].expense > 0
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
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top categories',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  for (final e in cats.take(4))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          CategoryBubble(
                            category: s.categoryById(e.key),
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.categoryById(e.key).name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            money.full(e.value),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.valueLabel,
    required this.isToday,
    required this.overBudget,
    required this.onTap,
  });

  final String label;
  final int value;
  final double ratio;
  final String valueLabel;
  final bool isToday;
  final bool overBudget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const maxBar = 118.0;
    final h = value == 0 ? 6.0 : math.max(10.0, maxBar * ratio);
    final base = overBudget ? Brand.expense : context.cs.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valueLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 26,
            height: h,
            decoration: BoxDecoration(
              gradient: value == 0
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [base, tint(base, 0.55)],
                    ),
              color: value == 0 ? context.softFill : null,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? context.cs.primary : context.cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
