import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_sheet.dart';
import 'widgets.dart';

/// Shared date-grouped ledger for the main list and individual account activity.
class TransactionList extends StatelessWidget {
  const TransactionList({
    super.key,
    required this.entries,
    this.header,
    this.bottomPadding = 24,
    this.showDateHeaders = true,
  });
  final List<Txn> entries;
  final Widget? header;
  final double bottomPadding;
  final bool showDateHeaders;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Txn>>{};
    for (final txn in entries) {
      (groups[dateKey(txn.date)] ??= []).add(txn);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final style = DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800);
        final scaler = MediaQuery.textScalerOf(context);
        double extent(DateTime date) {
          final available =
              (box.maxWidth - 32 - 24 - 15 - 16 - scaler.scale(28)).clamp(
                1.0,
                double.infinity,
              );
          final painter = TextPainter(
            text: TextSpan(text: fmtDayLong(date), style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout(maxWidth: available);
          final height = painter.height < 18 ? 46.0 : painter.height + 28;
          painter.dispose();
          return height;
        }

        return CustomScrollView(
          slivers: [
            if (header != null) SliverToBoxAdapter(child: header),
            if (entries.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No records found',
                  subtitle: 'Add a record or try another search.',
                ),
              )
            else ...[
              for (final group in groups.entries)
                SliverMainAxisGroup(
                  key: ValueKey(group.key),
                  slivers: [
                    if (showDateHeaders)
                      SliverPersistentHeader(
                        key: ValueKey('transaction-date-${group.key}'),
                        pinned: true,
                        delegate: _DateHeaderDelegate(
                          date: group.value.first.date,
                          extent: extent(group.value.first.date),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: SliverList.builder(
                        itemCount: group.value.length,
                        itemBuilder: (context, index) => Column(
                          children: [
                            if (index > 0) const Divider(height: 1),
                            TransactionRecordRow(txn: group.value[index]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
            ],
          ],
        );
      },
    );
  }
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DateHeaderDelegate({required this.date, required this.extent});
  final DateTime date;
  final double extent;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  bool shouldRebuild(covariant _DateHeaderDelegate old) =>
      old.date != date || old.extent != extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    key: ValueKey('transaction-date-band-${dateKey(date)}'),
    color: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.cs.primaryContainer,
          borderRadius: BorderRadius.circular(Brand.controlRadius),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: context.cs.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fmtDayLong(date),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: context.cs.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              fmtWeekday(date).substring(0, 3),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.cs.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TransactionRecordRow extends StatelessWidget {
  const TransactionRecordRow({super.key, required this.txn});
  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final balance = s.balanceAfter(txn);
    return InkWell(
      onTap: () => showEntrySheet(context, edit: txn),
      borderRadius: BorderRadius.circular(Brand.controlRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: TransactionRecordDetails(txn: txn, balance: balance),
      ),
    );
  }
}
