import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// A labelled money bar with the exact amount available on long press.
class ChartValueBar extends StatelessWidget {
  const ChartValueBar({
    super.key,
    required this.value,
    required this.maximum,
    required this.money,
    required this.color,
    required this.description,
  });

  final BigInt value;
  final BigInt maximum;
  final MoneyFormat money;
  final Color color;
  final String description;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '$description: ${money.full(value)}',
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (value > BigInt.zero) ...[
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money.compact(value),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: 26,
          height: value == BigInt.zero || maximum == BigInt.zero
              ? 3
              : math.max(5.0, 118 * minorRatio(value, maximum)),
          decoration: BoxDecoration(
            color: value == BigInt.zero ? context.softFill : color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    ),
  );
}
