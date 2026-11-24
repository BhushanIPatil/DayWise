import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import 'widgets.dart';

/// Shared Income / Expense control for records and recurring entries.
class TransactionTypeToggle extends StatelessWidget {
  const TransactionTypeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TxType value;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, TxType type, Color color) {
      final selected = value == type;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () {
              if (!selected) {
                tapHaptic();
                onChanged(type);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(Brand.controlRadius),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(Brand.controlRadius),
      ),
      child: Row(
        children: [
          segment('Income', TxType.income, Brand.income),
          segment('Expense', TxType.expense, Brand.expense),
        ],
      ),
    );
  }
}
