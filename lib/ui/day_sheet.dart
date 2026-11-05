import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_sheet.dart';
import 'widgets.dart';

Future<void> showDaySheet(BuildContext context, DateTime day) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DaySheet(initial: dateOnly(day)),
  );
}

/// Everything that happened on one day, with quick add buttons and prev/next day.
class DaySheet extends StatefulWidget {
  const DaySheet({super.key, required this.initial});
  final DateTime initial;

  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
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
    final entries = s.forDay(_day);
    final totals = s.dayTotals(_day);
    final budget = s.dailyBudgetMinor;
    final left = budget - totals.expense;
    final isToday = sameDay(_day, DateTime.now());

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: context.cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left_rounded, size: 28)),
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
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        Text(fmtDayLong(_day), style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right_rounded, size: 28)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                StatChip(label: 'Spent', value: money.full(totals.expense), color: Brand.expense),
                const SizedBox(width: 8),
                StatChip(label: 'Income', value: money.full(totals.income), color: Brand.income),
                const SizedBox(width: 8),
                StatChip(label: 'Net', value: money.signed(totals.net)),
              ],
            ),
          ),
          if (budget > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Icon(
                    left >= 0 ? Icons.savings_outlined : Icons.warning_amber_rounded,
                    size: 16,
                    color: left >= 0 ? Brand.income : Brand.expense,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    left >= 0
                        ? '${money.full(left)} left of today\'s ${money.full(budget)} budget'
                        : 'Over the daily budget by ${money.full(-left)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: left >= 0 ? context.cs.onSurfaceVariant : Brand.expense,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Flexible(
            child: entries.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Nothing recorded',
                    subtitle: 'Tap a button below to add an expense or income for this day.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => EntryTile(
                      txn: entries[i],
                      onTap: () => showEntrySheet(context, edit: entries[i]),
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 14 + MediaQuery.paddingOf(context).bottom),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Brand.expense),
                      onPressed: () => showEntrySheet(context, date: _day, type: TxType.expense),
                      icon: const Icon(Icons.remove_rounded),
                      label: const Text('Expense', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Brand.income),
                      onPressed: () => showEntrySheet(context, date: _day, type: TxType.income),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Income', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
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
