import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'day_sheet.dart';
import 'search_page.dart';
import 'widgets.dart';

/// Home screen: a swipeable month calendar where every day shows what was spent.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const int _baseYear = 2000;
  static const int _pageCount = 12 * 100; // Jan 2000 .. Dec 2099

  late final PageController _pc;
  late DateTime _focused; // first day of the visible month
  DateTime? _selected;

  static int _pageFor(DateTime d) => (d.year - _baseYear) * 12 + d.month - 1;
  static DateTime _monthFor(int page) => DateTime(_baseYear, 1 + page);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focused = DateTime(now.year, now.month);
    _pc = PageController(initialPage: _pageFor(_focused));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _goTo(DateTime month) {
    final target = math.max(0, math.min(_pageCount - 1, _pageFor(month)));
    final current = _pc.hasClients ? (_pc.page ?? target.toDouble()).round() : target;
    if ((target - current).abs() > 2) {
      _pc.jumpToPage(target);
    } else {
      _pc.animateToPage(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _focused,
      firstDate: DateTime(_baseYear),
      lastDate: DateTime(_baseYear + 99, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Jump to month',
    );
    if (d != null) _goTo(DateTime(d.year, d.month));
  }

  void _openDay(DateTime d) {
    setState(() => _selected = d);
    showDaySheet(context, d);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final totals = s.monthTotals(_focused.year, _focused.month);
    final now = DateTime.now();
    final onCurrent = _focused.year == now.year && _focused.month == now.month;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _goTo(DateTime(_focused.year, _focused.month - 1)),
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickMonth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              fmtMonth(_focused),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                            ),
                            Icon(Icons.expand_more_rounded, color: context.cs.onSurfaceVariant),
                          ],
                        ),
                        Text('${_focused.year}', style: TextStyle(fontSize: 12.5, color: context.cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _goTo(DateTime(_focused.year, _focused.month + 1)),
                  icon: const Icon(Icons.chevron_right_rounded, size: 30),
                ),
                IconButton(
                  tooltip: 'Today',
                  onPressed: onCurrent ? null : () => _goTo(DateTime(now.year, now.month)),
                  icon: const Icon(Icons.today_rounded),
                ),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchPage())),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: _SummaryCard(month: _focused, totals: totals),
          ),
          _WeekdayRow(weekStart: s.weekStart),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pageCount,
              onPageChanged: (i) {
                tapHaptic();
                setState(() => _focused = _monthFor(i));
              },
              itemBuilder: (context, i) => _MonthGrid(
                month: _monthFor(i),
                selected: _selected,
                onTap: _openDay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.month, required this.totals});
  final DateTime month;
  final Totals totals;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final budget = s.monthlyBudgetMinor;
    final progress = budget > 0 ? math.min(1.0, totals.expense / budget) : 0.0;
    final over = budget > 0 && totals.expense > budget;

    return GlassCard(
      gradient: accentGradient(context.cs.primary),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent in ${fmtMonth(month)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money.full(totals.expense),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
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
                  _mini('Income', money.full(totals.income)),
                  const SizedBox(height: 6),
                  _mini('Balance', money.signed(totals.net)),
                ],
              ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(over ? const Color(0xFFFFD166) : Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              over
                  ? 'Over budget by ${money.full(totals.expense - budget)}'
                  : '${money.full(budget - totals.expense)} left of ${money.full(budget)}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ],
      );
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.weekStart});
  final int weekStart;

  @override
  Widget build(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  names[(weekStart - 1 + i) % 7],
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selected, required this.onTap});
  final DateTime month;
  final DateTime? selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = (first.weekday - s.weekStart + 7) % 7;
    final rows = ((lead + daysInMonth) / 7).ceil();
    final today = dateOnly(DateTime.now());

    var maxExpense = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      final t = s.dayTotals(DateTime(month.year, month.month, d));
      if (t.expense > maxExpense) maxExpense = t.expense;
    }

    return LayoutBuilder(
      builder: (context, box) {
        final cellH = math.max(60.0, math.min(84.0, box.maxHeight / 6));
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
          child: Column(
            children: [
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: _cell(context, s, r * 7 + c - lead + 1, daysInMonth, cellH, maxExpense, today),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, AppState s, int day, int daysInMonth, double h, int maxExpense, DateTime today) {
    if (day < 1 || day > daysInMonth) return SizedBox(height: h);
    final date = DateTime(month.year, month.month, day);
    final totals = s.dayTotals(date);
    return _DayCell(
      day: day,
      height: h,
      totals: totals,
      maxExpense: maxExpense,
      isToday: sameDay(date, today),
      isSelected: selected != null && sameDay(date, selected!),
      overBudget: s.dailyBudgetMinor > 0 && totals.expense > s.dailyBudgetMinor,
      money: s.money,
      onTap: () => onTap(date),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.height,
    required this.totals,
    required this.maxExpense,
    required this.isToday,
    required this.isSelected,
    required this.overBudget,
    required this.money,
    required this.onTap,
  });

  final int day;
  final double height;
  final Totals totals;
  final int maxExpense;
  final bool isToday;
  final bool isSelected;
  final bool overBudget;
  final MoneyFormat money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final hasExp = totals.expense > 0;
    final hasInc = totals.income > 0;
    final intensity = (hasExp && maxExpense > 0) ? totals.expense / maxExpense : 0.0;

    Color bg = Colors.transparent;
    if (hasExp) {
      bg = tint(Brand.expense, 0.10 + 0.30 * intensity);
    } else if (hasInc) {
      bg = tint(Brand.income, 0.12);
    }

    Border? border;
    if (isSelected) {
      border = Border.all(color: cs.primary, width: 2);
    } else if (overBudget) {
      border = Border.all(color: tint(Brand.expense, 0.75), width: 1.2);
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        height: height - 4,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              tapHaptic();
              onTap();
            },
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: border),
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: isToday ? cs.primary : Colors.transparent, shape: BoxShape.circle),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isToday ? Colors.white : cs.onSurface,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (hasExp)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money.compact(totals.expense),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.isDark ? const Color(0xFFFF8FA3) : const Color(0xFFD62F4E),
                        ),
                      ),
                    ),
                  if (hasInc)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+${money.compact(totals.income)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.isDark ? const Color(0xFF5FE3B8) : const Color(0xFF0B8F69),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
