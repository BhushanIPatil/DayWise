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
    final types = [
      if (type == null || type == TxType.income) TxType.income,
      if (type == null || type == TxType.expense) TxType.expense,
    ];
    final rows = {
      for (final t in types) t: categoryTotals(entries, t, state.categoryById),
    };
    final totals = {
      for (final t in types)
        t: rows[t]!.fold<BigInt>(
          BigInt.zero,
          (sum, row) => sum + row.amountMinor,
        ),
    };
    final categories = <String, Category>{};
    final amounts = <String, BigInt>{};
    for (final group in rows.values) {
      for (final row in group) {
        categories[row.category.id] = row.category;
        amounts[row.category.id] =
            (amounts[row.category.id] ?? BigInt.zero) + row.amountMinor;
      }
    }
    final ordered = categories.values.toList()
      ..sort((a, b) {
        final amount = amounts[b.id]!.compareTo(amounts[a.id]!);
        return amount != 0 ? amount : a.name.compareTo(b.name);
      });
    final byCategory = {
      for (final t in types)
        t: {for (final row in rows[t]!) row.category.id: row},
    };
    return ListView(
      key: const PageStorageKey('category-analysis'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type == null ? 'Income and expense' : _label(type!),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final t in types)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(_label(t)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.money.full(totals[t]!),
                          key: ValueKey('category-total-${t.name}'),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _color(t),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'By category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Percentages of total income or expense',
                style: TextStyle(
                  fontSize: 12,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              for (final category in ordered) ...[
                if (category == ordered.first)
                  const SizedBox(height: 16)
                else
                  Divider(height: 28, color: context.cs.outlineVariant),
                Row(
                  children: [
                    Icon(
                      categoryIcons[category.icon] ?? categoryIcons['other'],
                      size: 22,
                      color: Color(category.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                for (final t in types)
                  _bar(
                    context,
                    state,
                    category,
                    t,
                    byCategory[t]![category.id],
                    totals[t]!,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _label(TxType type) => type == TxType.income ? 'Income' : 'Expense';
  Color _color(TxType type) =>
      type == TxType.income ? Brand.income : Brand.expense;

  Widget _bar(
    BuildContext context,
    AppState state,
    Category category,
    TxType groupType,
    CategoryTotal? row,
    BigInt total,
  ) {
    final amount = row?.amountMinor ?? BigInt.zero;
    final count = row?.count ?? 0;
    return InkWell(
      key: ValueKey('category-row-${groupType.name}-${category.id}'),
      borderRadius: BorderRadius.circular(Brand.controlRadius),
      onTap: count == 0
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CategoryRecords(
                  categoryId: category.id,
                  type: groupType,
                  from: from,
                  to: to,
                  query: query,
                ),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _label(groupType),
                  style: TextStyle(color: _color(groupType)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.money.full(amount),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (count > 0)
                  const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${(minorRatio(amount, total) * 100).toStringAsFixed(1)}% · $count ${count == 1 ? 'transaction' : 'transactions'}',
              style: TextStyle(
                fontSize: 12,
                color: context.cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: minorRatio(amount, total),
                minHeight: 7,
                color: _color(groupType),
                backgroundColor: context.softFill,
              ),
            ),
          ],
        ),
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
