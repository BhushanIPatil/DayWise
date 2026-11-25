import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_sheet.dart';
import 'accounts_page.dart';
import 'record_search.dart';
import 'report_export.dart';
import 'widgets.dart';
import 'date_budget_indicators.dart';
import 'record_view_options.dart';
import 'transaction_list.dart';

Future<void> showDayPage(
  BuildContext context,
  DateTime day, {
  RecordViewOptions? options,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => DayPage(initial: dateOnly(day), options: options),
    ),
  );
}

/// Everything that happened on one day, with quick add buttons and prev/next day.
class DayPage extends StatefulWidget {
  const DayPage({super.key, required this.initial, this.options});
  final DateTime initial;
  final RecordViewOptions? options;

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  late DateTime _day;
  late final RecordViewOptions _view;
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _day = dateOnly(widget.initial);
    _view = RecordViewOptions()
      ..ascending = widget.options?.ascending ?? false
      ..type = widget.options?.type;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _move(int delta) {
    tapHaptic();
    setState(() => _day = addDays(_day, delta));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final matches = _query.trim().isEmpty
        ? null
        : s.search(_query, limit: s.all.length).toSet();
    final entries = _view.apply(
      s.forDay(_day).where((t) => matches == null || matches.contains(t)),
    );
    final type = _view.type;
    final totals = Totals(
      entries
          .where((t) => t.isIncome)
          .fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amountMinor),
      entries
          .where((t) => !t.isIncome)
          .fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amountMinor),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const BackButton(),
                Expanded(
                  child: AccountSwitcher(
                    viewToggle: IconButton(
                      tooltip: 'Search',
                      onPressed: () => setState(() => _searching = true),
                      icon: const Icon(Icons.search_rounded),
                    ),
                    actions: ReportExport(
                      title: 'Day',
                      entries: entries,
                      from: _day,
                      to: _day,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v < -200) _move(1);
                        if (v > 200) _move(-1);
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${fmtWeekday(_day)}, ${fmtDayLong(_day)}',
                          key: const ValueKey('day-heading'),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  ),
                  RecordSortButton(
                    options: _view,
                    showDateSort: false,
                    onChanged: () => setState(() {}),
                  ),
                ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  if (type != TxType.income)
                    StatChip(
                      label: 'Spent',
                      value: money.full(totals.expense),
                      color: Brand.expense,
                    ),
                  if (type == null) const SizedBox(width: 8),
                  if (type != TxType.expense)
                    StatChip(
                      label: 'Income',
                      value: money.full(totals.income),
                      color: Brand.income,
                    ),
                  if (type == null) const SizedBox(width: 8),
                  if (type == null)
                    StatChip(label: 'Net', value: money.signed(totals.net)),
                ],
              ),
            ),
            if (type != TxType.income)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: DateBudgetIndicators(date: _day),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Nothing recorded',
                      subtitle:
                          'Tap a button below to add an expense or income for this day.',
                    )
                  : TransactionList(entries: entries, showDateHeaders: false),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.expense,
                        ),
                        onPressed: () => showEntrySheet(
                          context,
                          date: _day,
                          type: TxType.expense,
                        ),
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text(
                          'Expense',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.income,
                        ),
                        onPressed: () => showEntrySheet(
                          context,
                          date: _day,
                          type: TxType.income,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          'Income',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
