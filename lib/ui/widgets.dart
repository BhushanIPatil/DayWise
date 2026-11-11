import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';

/// Soft rounded surface used for every card in the app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 24,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final r = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? context.cardColor : null,
        gradient: gradient,
        borderRadius: r,
        border: Border.all(
          color: dark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
        ),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14201A4D),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Two soft colour blobs behind the whole app.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  Widget _blob(Color c, double size, double o) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [tint(c, o), tint(c, 0)]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = context.cs.primary;
    final dark = context.isDark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -100,
            child: _blob(a, 380, dark ? 0.30 : 0.20),
          ),
          Positioned(
            top: 300,
            left: -180,
            child: _blob(Brand.expense, 360, dark ? 0.12 : 0.08),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: _blob(Brand.income, 340, dark ? 0.10 : 0.08),
          ),
        ],
      ),
    );
  }
}

class CategoryBubble extends StatelessWidget {
  const CategoryBubble({super.key, required this.category, this.size = 44});
  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = category.colorValue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint(c, 0.16),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(category.iconData, color: c, size: size * 0.5),
    );
  }
}

/// One transaction row (used in the day sheet and in search).
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.txn,
    required this.onTap,
    this.showDate = false,
  });
  final Txn txn;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cat = s.categoryOf(txn);
    final color = txn.isIncome ? Brand.income : Brand.expense;
    final sub = <String>[
      if (showDate) fmtDayLong(txn.date),
      fmtTime(txn.date),
      if (s.selectedAccountId == null) s.accountById(txn.accountId).name,
      if (txn.note.isNotEmpty) txn.note,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            CategoryBubble(category: cat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              s.money.signed(txn.signed),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tint(context.cs.primary, 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: context.cs.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "‹  October 2026  ›" selector used by the week and insights pages.
class PeriodNavigator extends StatelessWidget {
  const PeriodNavigator({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPrev,
    required this.onNext,
  });
  final String title;
  final String? subtitle;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 30),
        ),
      ],
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.softFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: context.cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void tapHaptic() => HapticFeedback.selectionClick();

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
