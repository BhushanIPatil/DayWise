import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    _day = widget.initial;
  }

  void _move(int delta) {
    tapHaptic();
    setState(() => _day = addDays(_day, delta));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final entries = (widget.options ?? RecordViewOptions()).apply(
      s.forDay(_day),
    );
    final type = widget.options?.type;
    final totals = Totals(
      entries
          .where((t) => t.isIncome)
          .fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amountMinor),
      entries
          .where((t) => !t.isIncome)
          .fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amountMinor),
    );
    final isToday = sameDay(_day, DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(
                children: [
                  const BackButton(),
                  IconButton(
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
                      child: Column(
                        children: [
                          Text(
                            isToday ? 'Today' : fmtWeekday(_day),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            fmtDayLong(_day),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  ),
                ],
              ),
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
                  : TransactionList(entries: entries),
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
