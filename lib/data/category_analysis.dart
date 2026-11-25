import 'models.dart';

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.amountMinor,
    required this.count,
  });
  final Category category;
  final BigInt amountMinor;
  final int count;
}

/// Resolve missing/deleted categories before grouping, and keep income and
/// expense totals separate so each percentage has a meaningful denominator.
List<CategoryTotal> categoryTotals(
  Iterable<Txn> entries,
  TxType type,
  Category Function(String) categoryById,
) {
  final amounts = <String, BigInt>{};
  final counts = <String, int>{};
  final categories = <String, Category>{};
  for (final txn in entries) {
    if (txn.type != type) continue;
    final category = categoryById(txn.categoryId);
    categories[category.id] = category;
    amounts[category.id] =
        (amounts[category.id] ?? BigInt.zero) + txn.amountMinor;
    counts[category.id] = (counts[category.id] ?? 0) + 1;
  }
  return [
    for (final entry in amounts.entries)
      CategoryTotal(
        category: categories[entry.key]!,
        amountMinor: entry.value,
        count: counts[entry.key]!,
      ),
  ]..sort((a, b) {
    final amount = b.amountMinor.compareTo(a.amountMinor);
    if (amount != 0) return amount;
    final name = a.category.name.toLowerCase().compareTo(
      b.category.name.toLowerCase(),
    );
    return name != 0 ? name : a.category.id.compareTo(b.category.id);
  });
}
