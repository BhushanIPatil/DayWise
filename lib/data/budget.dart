class AccountBudget {
  const AccountBudget({this.monthlyMinor = 0, this.dailyMinor = 0});
  final int monthlyMinor;
  final int dailyMinor;
  bool get isEmpty => monthlyMinor == 0 && dailyMinor == 0;
  Map<String, int> toMap() => {
    'monthlyMinor': monthlyMinor,
    'dailyMinor': dailyMinor,
  };
}

Map<String, AccountBudget>? decodeAccountBudgets(Object? raw) {
  if (raw is! Map) return null;
  final result = <String, AccountBudget>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || entry.value is! Map) continue;
    final row = entry.value as Map;
    int amount(String key) =>
        row[key] is num ? (row[key] as num).toInt().clamp(0, 99999999999) : 0;
    final budget = AccountBudget(
      monthlyMinor: amount('monthlyMinor'),
      dailyMinor: amount('dailyMinor'),
    );
    if (!budget.isEmpty) result[entry.key as String] = budget;
  }
  return result;
}
