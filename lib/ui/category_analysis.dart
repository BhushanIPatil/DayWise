import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/category_analysis.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'categories_page.dart';
import 'transaction_list.dart';
import 'widgets.dart';

enum AnalysisView { overview, categories }

/// Always sits immediately below the period controls in analysis screens.
class AnalysisViewToggle extends StatelessWidget {
  const AnalysisViewToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final AnalysisView value;
  final ValueChanged<AnalysisView> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: SizedBox(
      width: double.infinity,
      child: SegmentedButton<AnalysisView>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: AnalysisView.overview, label: Text('Overview')),
          ButtonSegment(
            value: AnalysisView.categories,
            label: Text('Categories'),
          ),
        ],
        selected: {value},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    ),
  );
}

class CategoryAnalysis extends StatelessWidget {
  const CategoryAnalysis({
    super.key,
    required this.entries,
    this.type,
    this.from,
    this.to,
    this.query = '',
  });
  final List<Txn> entries;
  final TxType? type;
  final DateTime? from;
  final DateTime? to;
  final String query;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (entries.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.category_outlined,
          title: 'No category data',
          subtitle: 'No records match the selected period and filters.',
        ),
      );
    }
    return ListView(
      key: const PageStorageKey('category-analysis'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        for (final groupType in [TxType.expense, TxType.income])
          if (type == null || type == groupType)
            _section(context, state, groupType),
      ],
    );
  }

  Widget _section(BuildContext context, AppState state, TxType groupType) {
    final rows = categoryTotals(entries, groupType, state.categoryById);
    final total = rows.fold<BigInt>(
      BigInt.zero,
      (sum, row) => sum + row.amountMinor,
    );
    final label = groupType == TxType.income ? 'Income' : 'Expense';
    return GlassCard(
      key: ValueKey('category-section-${groupType.name}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label by category',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            state.money.full(total),
            key: ValueKey('category-total-${groupType.name}'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: groupType == TxType.income ? Brand.income : Brand.expense,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Percentages of total ${label.toLowerCase()}',
            style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('No ${label.toLowerCase()} records in this period.'),
            ),
          for (final row in rows)
            InkWell(
              key: ValueKey(
                'category-row-${groupType.name}-${row.category.id}',
              ),
              borderRadius: BorderRadius.circular(Brand.controlRadius),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _CategoryRecords(
                    categoryId: row.category.id,
                    type: groupType,
                    from: from,
                    to: to,
                    query: query,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          categoryIcons[row.category.icon] ??
                              categoryIcons['other'],
                          size: 22,
                          color: Color(row.category.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            row.category.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.money.full(row.amountMinor),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(minorRatio(row.amountMinor, total) * 100).toStringAsFixed(1)}% · ${row.count} ${row.count == 1 ? 'transaction' : 'transactions'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: minorRatio(row.amountMinor, total),
                        minHeight: 7,
                        color: Color(row.category.color),
                        backgroundColor: context.softFill,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A live list: editing or deleting a record immediately updates this selection.
class _CategoryRecords extends StatelessWidget {
  const _CategoryRecords({
    required this.categoryId,
    required this.type,
    this.from,
    this.to,
    this.query = '',
  });
  final String categoryId;
  final TxType type;
  final DateTime? from;
  final DateTime? to;
  final String query;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(categoryId);
    final matches = query.trim().isEmpty
        ? null
        : state.search(query, limit: state.all.length).toSet();
    final entries = state
        .recordsInRange(from, to)
        .where(
          (txn) =>
              txn.type == type &&
              state.categoryById(txn.categoryId).id == categoryId &&
              (matches == null ||
                  matches.contains(txn) ||
                  category.name.toLowerCase().contains(
                    query.trim().toLowerCase(),
                  )),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${category.name} · ${type == TxType.income ? 'Income' : 'Expense'}',
        ),
      ),
      body: TransactionList(entries: entries),
    );
  }
}
