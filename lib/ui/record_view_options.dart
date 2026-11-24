import 'package:flutter/material.dart';

import '../data/models.dart';

enum RecordSortChoice { ascending, descending, both, income, expense }

/// Date order and record type are independent choices.
class RecordViewOptions {
  bool ascending = false;
  TxType? type;

  List<Txn> apply(Iterable<Txn> entries) {
    final result = entries
        .where((txn) => type == null || txn.type == type)
        .toList();
    result.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      final order = byDate != 0 ? byDate : (a.id ?? 0).compareTo(b.id ?? 0);
      return ascending ? order : -order;
    });
    return result;
  }
}

class RecordSortButton extends StatelessWidget {
  const RecordSortButton({
    super.key,
    required this.options,
    required this.onChanged,
  });
  final RecordViewOptions options;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<RecordSortChoice>(
    tooltip: 'Sort and record type',
    icon: const Icon(Icons.sort_rounded),
    itemBuilder: (_) => [
      CheckedPopupMenuItem(
        value: RecordSortChoice.ascending,
        checked: options.ascending,
        child: const Text('Date ascending'),
      ),
      CheckedPopupMenuItem(
        value: RecordSortChoice.descending,
        checked: !options.ascending,
        child: const Text('Date descending'),
      ),
      const PopupMenuDivider(),
      CheckedPopupMenuItem(
        value: RecordSortChoice.both,
        checked: options.type == null,
        child: const Text('Income/Expense'),
      ),
      CheckedPopupMenuItem(
        value: RecordSortChoice.income,
        checked: options.type == TxType.income,
        child: const Text('Income'),
      ),
      CheckedPopupMenuItem(
        value: RecordSortChoice.expense,
        checked: options.type == TxType.expense,
        child: const Text('Expense'),
      ),
    ],
    onSelected: (choice) {
      switch (choice) {
        case RecordSortChoice.ascending:
          options.ascending = true;
        case RecordSortChoice.descending:
          options.ascending = false;
        case RecordSortChoice.both:
          options.type = null;
        case RecordSortChoice.income:
          options.type = TxType.income;
        case RecordSortChoice.expense:
          options.type = TxType.expense;
      }
      onChanged();
    },
  );
}
