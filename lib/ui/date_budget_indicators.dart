import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/format.dart';
import '../state/app_state.dart';

/// Daily spending and the full month's budget balance for the selected date.
class DateBudgetIndicators extends StatelessWidget {
  const DateBudgetIndicators({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget indicator(String label, BigInt spent, int budget) {
      final limit = BigInt.from(budget);
      final over = spent > limit;
      final color = over
          ? Brand.expense
          : spent == limit
          ? Colors.orange
          : Brand.income;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: ${s.money.full(spent)} / ${s.money.full(budget)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: minorRatio(spent, limit),
              minHeight: 4,
              color: color,
              backgroundColor: context.softFill,
            ),
            const SizedBox(height: 3),
            Text(
              over
                  ? 'Over budget by ${s.money.full(spent - limit)}'
                  : '${s.money.full(limit - spent)} remaining',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (s.dailyBudgetMinor > 0)
          indicator(
            'Daily budget',
            s.dayTotals(date).expense,
            s.dailyBudgetMinor,
          ),
        if (s.monthlyBudgetMinor > 0)
          indicator(
            'Monthly budget',
            s.monthTotals(date.year, date.month).expense,
            s.monthlyBudgetMinor,
          ),
      ],
    );
  }
}
