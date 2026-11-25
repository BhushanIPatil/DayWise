import 'categories_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';

/// Scroll the fields while the action remains at the bottom of the visible form.
class PinnedForm extends StatelessWidget {
  const PinnedForm({
    super.key,
    required this.child,
    required this.action,
    this.expand = false,
    this.contentPadding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Widget action;
  final bool expand;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
    children: [
      Flexible(
        fit: expand ? FlexFit.tight : FlexFit.loose,
        child: SingleChildScrollView(padding: contentPadding, child: child),
      ),
      Container(
        decoration: BoxDecoration(
          color: context.cs.surface,
          border: Border(top: BorderSide(color: context.theme.dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: action,
          ),
        ),
      ),
    ],
  );
}

/// Soft rounded surface used for every card in the app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = Brand.cardRadius,
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

class TransactionTypeBadge extends StatelessWidget {
  const TransactionTypeBadge({super.key, required this.type});
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final c = type == TxType.income ? Brand.income : Brand.expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint(c, 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type == TxType.income ? 'Income' : 'Expense',
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AccountBadge extends StatelessWidget {
  const AccountBadge({super.key, required this.account});
  final MoneyAccount account;
  @override
  Widget build(BuildContext context) {
    final background = Color.alphaBlend(
      tint(Color(account.color), context.isDark ? .28 : .12),
      context.cs.surface,
    );
    final foreground = background.computeLuminance() > .179
        ? Colors.black
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: tint(Color(account.color), .45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        account.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// Shared columns keep notes separate from transaction amounts and balances.
class TransactionRecordDetails extends StatelessWidget {
  const TransactionRecordDetails({
    super.key,
    required this.txn,
    this.showDate = false,
    this.balance,
  });
  final Txn txn;
  final bool showDate;
  final BigInt? balance;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final color = txn.isIncome ? Brand.income : Brand.expense;
    final category = s.categoryById(txn.categoryId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      categoryIcons[category.icon] ?? categoryIcons['other'],
                      color: Color(category.color),
                      size: 18,
                      semanticLabel: category.name,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      txn.note.isEmpty
                          ? (txn.isIncome ? 'Income' : 'Expense')
                          : txn.note,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    s.money.signed(txn.signed),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fmtTime(txn.date),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AccountBadge(account: s.accountById(txn.accountId)),
                      ],
                    ),
                  ),
                  if (showDate)
                    Text(
                      fmtDayLong(txn.date),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (balance != null) ...[
                    Text(
                      'Balance after',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        s.money.full(balance!),
                        key: ValueKey('transaction-balance-${txn.id}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: balance! < BigInt.zero
                              ? Brand.expense
                              : context.cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
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
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(Brand.controlRadius),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: TransactionRecordDetails(txn: txn, showDate: showDate),
    ),
  );
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
const periodLabelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w800);

class PeriodNavigator extends StatelessWidget {
  const PeriodNavigator({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPrev,
    required this.onNext,
    this.onSelect,
  });
  final String title;
  final String? subtitle;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
        ),
        Expanded(
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(Brand.controlRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                subtitle == null ? title : '$title $subtitle',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: periodLabelStyle,
              ),
            ),
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
          borderRadius: BorderRadius.circular(Brand.controlRadius),
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
