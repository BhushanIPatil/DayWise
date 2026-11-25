import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'day_page.dart';
import 'record_search.dart';
import 'widgets.dart';
import 'report_export.dart';
import 'accounts_page.dart';
import 'report_period.dart';
import 'upcoming_recurring.dart';
import 'record_view_options.dart';

/// Home screen: a swipeable month calendar where every day shows what was spent.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.onWeekView});
  final VoidCallback? onWeekView;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const int _baseYear = 2000;
  static const int _pageCount = 12 * 100; // Jan 2000 .. Dec 2099

  late final PageController _pc;
  late DateTime _focused; // first day of the visible month
  DateTime? _selected;
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';
  final _view = RecordViewOptions();

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
    _searchController.dispose();
    super.dispose();
  }

  void _goTo(DateTime month) {
    final target = math.max(0, math.min(_pageCount - 1, _pageFor(month)));
    final current = _pc.hasClients
        ? (_pc.page ?? target.toDouble()).round()
        : target;
    if ((target - current).abs() > 2) {
      _pc.jumpToPage(target);
    } else {
      _pc.animateToPage(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _pickMonth() async {
    final d = await showMonthYearPicker(context, _focused);
    if (d != null && mounted) _goTo(d);
  }

  void _openDay(DateTime d) {
    setState(() => _selected = d);
    showDayPage(context, d, options: _view);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final totals = _view.filterTotals(
      s.monthTotals(_focused.year, _focused.month),
    );

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
              title: 'Calendar ${fmtMonth(_focused)} ${_focused.year}',
              from: _focused,
              to: DateTime(_focused.year, _focused.month + 1, 0),
              entries: _view.apply(
                s.recordsInRange(
                  _focused,
                  DateTime(_focused.year, _focused.month + 1, 0),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: PeriodNavigator(
                  onSelect: _pickMonth,
                  title: fmtMonth(_focused),
                  subtitle: '${_focused.year}',
                  onPrev: () =>
                      _goTo(DateTime(_focused.year, _focused.month - 1)),
                  onNext: () =>
                      _goTo(DateTime(_focused.year, _focused.month + 1)),
                ),
              ),
              IconButton(
                tooltip: 'Switch to week',
                onPressed: widget.onWeekView,
                icon: const Icon(Icons.view_week_rounded),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: _SummaryCard(
              month: _focused,
              totals: totals,
              type: _view.type,
            ),
          ),
          _WeekdayRow(weekStart: s.weekStart),
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
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
                    options: _view,
                  ),
                ),
                if (_query.trim().isNotEmpty)
                  Positioned.fill(
                    child: RecordSearchResults(query: _query, options: _view),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.month, required this.totals, this.type});
  final DateTime month;
  final Totals totals;
  final TxType? type;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final budget = type == TxType.income ? 0 : s.monthlyBudgetMinor;
    final progress = minorRatio(totals.expense, budget);
    final over = budget > 0 && totals.expense > BigInt.from(budget);

    return GlassCard(
      gradient: accentGradient(context.cs.primary),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      radius: Brand.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${type == null
                          ? 'Balance'
                          : type == TxType.income
                          ? 'Income'
                          : 'Expense'} in ${fmtMonth(month)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        type == null
                            ? money.signed(totals.net)
                            : money.full(
                                type == TxType.income
                                    ? totals.income
                                    : totals.expense,
                              ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (type != TxType.expense)
                          _mini(
                            'Income',
                            money.full(totals.income),
                            const Color(0xFF8FF0CD),
                          ),
                        if (type == null) const SizedBox(height: 6),
                        if (type != TxType.income)
                          _mini(
                            'Expense',
                            money.full(totals.expense),
                            const Color(0xFFFFB5C4),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(Brand.controlRadius),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(
                  over ? const Color(0xFFFFD166) : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              over
                  ? 'Over budget by ${money.full(totals.expense - BigInt.from(budget))}'
                  : '${money.full(BigInt.from(budget) - totals.expense)} left of ${money.full(budget)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
      ),
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
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.onTap,
    required this.options,
  });
  final DateTime month;
  final DateTime? selected;
  final ValueChanged<DateTime> onTap;
  final RecordViewOptions options;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = (first.weekday - s.weekStart + 7) % 7;
    final rows = ((lead + daysInMonth) / 7).ceil();
    final today = dateOnly(DateTime.now());

    var maxExpense = BigInt.zero;
    for (var d = 1; d <= daysInMonth; d++) {
      final t = options.filterTotals(
        s.dayTotals(DateTime(month.year, month.month, d)),
      );
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
                        child: _cell(
                          context,
                          s,
                          r * 7 + c - lead + 1,
                          daysInMonth,
                          cellH,
                          maxExpense,
                          today,
                        ),
                      ),
                  ],
                ),
              const UpcomingRecurringSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(
    BuildContext context,
    AppState s,
    int day,
    int daysInMonth,
    double h,
    BigInt maxExpense,
    DateTime today,
  ) {
    if (day < 1 || day > daysInMonth) return SizedBox(height: h);
    final date = DateTime(month.year, month.month, day);
    final totals = options.filterTotals(s.dayTotals(date));
    return _DayCell(
      day: day,
      height: h,
      totals: totals,
      maxExpense: maxExpense,
      isToday: sameDay(date, today),
      isSelected: selected != null && sameDay(date, selected!),
      overBudget:
          s.dailyBudgetMinor > 0 &&
          totals.expense > BigInt.from(s.dailyBudgetMinor),
      dailyBudgetUsage: options.type != TxType.income && s.dailyBudgetMinor > 0
          ? minorRatio(totals.expense, s.dailyBudgetMinor, clamp: false)
          : null,
      monthlyBudgetUsage:
          options.type != TxType.income && s.monthlyBudgetMinor > 0
          ? minorRatio(
              s.monthTotals(date.year, date.month).expense,
              s.monthlyBudgetMinor,
              clamp: false,
            )
          : null,
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
    this.dailyBudgetUsage,
    this.monthlyBudgetUsage,
    required this.money,
    required this.onTap,
  });

  final int day;
  final double height;
  final Totals totals;
  final BigInt maxExpense;
  final bool isToday;
  final bool isSelected;
  final bool overBudget;
  final double? dailyBudgetUsage;
  final double? monthlyBudgetUsage;
  final MoneyFormat money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final hasExp = totals.expense > BigInt.zero;
    final hasInc = totals.income > BigInt.zero;
    final intensity = (hasExp && maxExpense > BigInt.zero)
        ? minorRatio(totals.expense, maxExpense)
        : 0.0;

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
          borderRadius: BorderRadius.circular(Brand.controlRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              tapHaptic();
              onTap();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Brand.controlRadius),
                border: border,
              ),
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday ? cs.primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
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
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (dailyBudgetUsage != null)
                            _budgetDot('Daily', dailyBudgetUsage!),
                          if (monthlyBudgetUsage != null)
                            _budgetDot('Monthly', monthlyBudgetUsage!),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (hasInc)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+${money.compact(totals.income)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.isDark
                              ? const Color(0xFF5FE3B8)
                              : const Color(0xFF0B8F69),
                        ),
                      ),
                    ),
                  if (hasExp)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money.compact(totals.expense),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.isDark
                              ? const Color(0xFFFF8FA3)
                              : const Color(0xFFD62F4E),
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

  Widget _budgetDot(String label, double usage) => Tooltip(
    message: '$label budget: ${(usage * 100).round()}% used',
    child: Padding(
      padding: const EdgeInsets.only(left: 1),
      child: Icon(
        Icons.circle,
        size: 5,
        color: usage > 1
            ? Brand.expense
            : usage >= 0.8
            ? Colors.orange
            : Brand.income,
      ),
    ),
  );
}
