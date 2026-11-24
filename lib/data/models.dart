import '../core/format.dart';

enum TxType { expense, income }

const String kDefaultAccountId = 'everyday';

class MoneyAccount {
  const MoneyAccount({
    required this.id,
    required this.name,
    Object openingBalanceMinor = 0,
    this.color = 0xFF6C5CE7,
  }) : _openingBalanceMinor = openingBalanceMinor;

  final String id;
  final String name;
  final Object _openingBalanceMinor;
  BigInt get openingBalanceMinor => readMinor(_openingBalanceMinor);
  final int color;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'opening_balance_minor': openingBalanceMinor.toString(),
    'color': color,
  };

  factory MoneyAccount.fromMap(Map<String, Object?> m) => MoneyAccount(
    id: m['id'] as String,
    name: m['name'] as String,
    openingBalanceMinor: readMinor(m['opening_balance_minor'] ?? 0),
    color: (m['color'] as num?)?.toInt() ?? 0xFF6C5CE7,
  );
}

const MoneyAccount kDefaultAccount = MoneyAccount(
  id: kDefaultAccountId,
  name: 'Everyday',
);

/// Legacy metadata kept for compatibility with older databases and backups.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.builtin = false,
    this.sort = 0,
  });

  final String id;
  final String name;
  final String icon;
  final int color;
  final TxType type;
  final bool builtin;
  final int sort;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'type': type.index,
    'builtin': builtin ? 1 : 0,
    'sort': sort,
  };

  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as String,
    name: m['name'] as String,
    icon: m['icon'] as String,
    color: (m['color'] as num).toInt(),
    type: (m['type'] as num).toInt() == 1 ? TxType.income : TxType.expense,
    builtin: ((m['builtin'] as num?)?.toInt() ?? 0) == 1,
    sort: (m['sort'] as num?)?.toInt() ?? 0,
  );
}

class Txn {
  const Txn({
    this.id,
    required this.date,
    required Object amountMinor,
    required this.type,
    this.categoryId = '',
    this.accountId = kDefaultAccountId,
    this.note = '',
    required this.createdAt,
  }) : _amountMinor = amountMinor;

  final int? id;
  final DateTime date; // local transaction date and time
  final Object _amountMinor;
  BigInt get amountMinor => readMinor(_amountMinor); // always positive
  final TxType type;
  // Retained only to read and round-trip older databases and backups.
  final String categoryId;
  final String accountId;
  final String note;
  final int createdAt; // epoch millis

  bool get isIncome => type == TxType.income;
  BigInt get signed => isIncome ? amountMinor : -amountMinor;

  Txn copyWith({
    int? id,
    DateTime? date,
    Object? amountMinor,
    TxType? type,
    String? categoryId,
    String? note,
    String? accountId,
  }) => Txn(
    id: id ?? this.id,
    date: date ?? this.date,
    amountMinor: amountMinor ?? this.amountMinor,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    accountId: accountId ?? this.accountId,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap({bool includeId = true}) => {
    if (includeId && id != null) 'id': id,
    'date': dateKey(date),
    'occurred_at': date.toIso8601String(),
    'account_id': accountId,
    'amount_minor': amountMinor.toString(),
    'type': type.index,
    'category_id': categoryId,
    'note': note,
    'created_at': createdAt,
  };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
    id: (m['id'] as num?)?.toInt(),
    date: m['occurred_at'] == null
        ? parseKey(m['date'] as String)
        : DateTime.parse(m['occurred_at'] as String),
    accountId: (m['account_id'] as String?) ?? kDefaultAccountId,
    amountMinor: readMinor(m['amount_minor']!),
    type: (m['type'] as num).toInt() == 1 ? TxType.income : TxType.expense,
    categoryId: (m['category_id'] as String?) ?? '',
    note: (m['note'] as String?) ?? '',
    createdAt: (m['created_at'] as num).toInt(),
  );
}

class Totals {
  const Totals(Object income, Object expense)
    : _income = income,
      _expense = expense;
  final Object _income;
  final Object _expense;
  BigInt get income => readMinor(_income);
  BigInt get expense => readMinor(_expense);
  static const Totals zero = Totals(0, 0);

  BigInt get net => income - expense;
  bool get isEmpty => income == BigInt.zero && expense == BigInt.zero;

  Totals operator +(Totals o) => Totals(income + o.income, expense + o.expense);
}
