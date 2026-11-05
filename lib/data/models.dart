import 'package:flutter/material.dart';

import '../core/format.dart';

enum TxType { expense, income }

const String kDefaultAccountId = 'everyday';

class MoneyAccount {
  const MoneyAccount({
    required this.id,
    required this.name,
    this.openingBalanceMinor = 0,
    this.color = 0xFF6C5CE7,
  });

  final String id;
  final String name;
  final int openingBalanceMinor;
  final int color;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'opening_balance_minor': openingBalanceMinor,
    'color': color,
  };

  factory MoneyAccount.fromMap(Map<String, Object?> m) => MoneyAccount(
    id: m['id'] as String,
    name: m['name'] as String,
    openingBalanceMinor: (m['opening_balance_minor'] as num?)?.toInt() ?? 0,
    color: (m['color'] as num?)?.toInt() ?? 0xFF6C5CE7,
  );
}

const MoneyAccount kDefaultAccount = MoneyAccount(
  id: kDefaultAccountId,
  name: 'Everyday',
);

/// Material icons that categories can use. Stored by key so release builds can
/// tree-shake the icon font (never build IconData from a number at runtime).
const Map<String, IconData> kCategoryIcons = {
  'restaurant': Icons.restaurant,
  'coffee': Icons.coffee,
  'groceries': Icons.shopping_basket,
  'car': Icons.directions_car,
  'fuel': Icons.local_gas_station,
  'bus': Icons.directions_bus,
  'shopping': Icons.shopping_bag,
  'bills': Icons.receipt_long,
  'home': Icons.home,
  'health': Icons.medical_services,
  'fitness': Icons.fitness_center,
  'movie': Icons.movie,
  'travel': Icons.flight,
  'school': Icons.school,
  'subscriptions': Icons.subscriptions,
  'gift': Icons.card_giftcard,
  'pets': Icons.pets,
  'kids': Icons.child_care,
  'phone': Icons.phone_android,
  'wifi': Icons.wifi,
  'build': Icons.build,
  'work': Icons.work,
  'game': Icons.sports_esports,
  'beauty': Icons.spa,
  'salary': Icons.payments,
  'business': Icons.storefront,
  'laptop': Icons.laptop_mac,
  'invest': Icons.trending_up,
  'savings': Icons.savings,
  'wallet': Icons.account_balance_wallet,
  'redeem': Icons.redeem,
  'other': Icons.category,
};

IconData iconFor(String key) => kCategoryIcons[key] ?? Icons.category;

const List<int> kCategoryColors = [
  0xFFFF7043,
  0xFFFF4D6D,
  0xFFE84393,
  0xFF9B59B6,
  0xFF6C5CE7,
  0xFF3F51B5,
  0xFF0984E3,
  0xFF00ACC1,
  0xFF00B894,
  0xFF2E9E5B,
  0xFFFDCB6E,
  0xFFFD9644,
];

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

  Color get colorValue => Color(color);
  IconData get iconData => iconFor(icon);

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

const Category kUncategorised = Category(
  id: '_none',
  name: 'Uncategorised',
  icon: 'other',
  color: 0xFF90A4AE,
  type: TxType.expense,
  builtin: true,
);

const List<Category> kDefaultCategories = [
  Category(
    id: 'food',
    name: 'Food & Dining',
    icon: 'restaurant',
    color: 0xFFFF7043,
    type: TxType.expense,
    builtin: true,
    sort: 0,
  ),
  Category(
    id: 'groceries',
    name: 'Groceries',
    icon: 'groceries',
    color: 0xFF2E9E5B,
    type: TxType.expense,
    builtin: true,
    sort: 1,
  ),
  Category(
    id: 'transport',
    name: 'Transport',
    icon: 'car',
    color: 0xFF0984E3,
    type: TxType.expense,
    builtin: true,
    sort: 2,
  ),
  Category(
    id: 'fuel',
    name: 'Fuel',
    icon: 'fuel',
    color: 0xFFFD9644,
    type: TxType.expense,
    builtin: true,
    sort: 3,
  ),
  Category(
    id: 'shopping',
    name: 'Shopping',
    icon: 'shopping',
    color: 0xFFE84393,
    type: TxType.expense,
    builtin: true,
    sort: 4,
  ),
  Category(
    id: 'bills',
    name: 'Bills & Utilities',
    icon: 'bills',
    color: 0xFF6C5CE7,
    type: TxType.expense,
    builtin: true,
    sort: 5,
  ),
  Category(
    id: 'rent',
    name: 'Rent & Home',
    icon: 'home',
    color: 0xFF3F51B5,
    type: TxType.expense,
    builtin: true,
    sort: 6,
  ),
  Category(
    id: 'health',
    name: 'Health',
    icon: 'health',
    color: 0xFFFF4D6D,
    type: TxType.expense,
    builtin: true,
    sort: 7,
  ),
  Category(
    id: 'entertainment',
    name: 'Entertainment',
    icon: 'movie',
    color: 0xFF9B59B6,
    type: TxType.expense,
    builtin: true,
    sort: 8,
  ),
  Category(
    id: 'travel',
    name: 'Travel',
    icon: 'travel',
    color: 0xFF00ACC1,
    type: TxType.expense,
    builtin: true,
    sort: 9,
  ),
  Category(
    id: 'education',
    name: 'Education',
    icon: 'school',
    color: 0xFF00B894,
    type: TxType.expense,
    builtin: true,
    sort: 10,
  ),
  Category(
    id: 'subscriptions',
    name: 'Subscriptions',
    icon: 'subscriptions',
    color: 0xFFFDCB6E,
    type: TxType.expense,
    builtin: true,
    sort: 11,
  ),
  Category(
    id: 'gifts',
    name: 'Gifts',
    icon: 'gift',
    color: 0xFFFF7675,
    type: TxType.expense,
    builtin: true,
    sort: 12,
  ),
  Category(
    id: 'other_exp',
    name: 'Other',
    icon: 'other',
    color: 0xFF90A4AE,
    type: TxType.expense,
    builtin: true,
    sort: 13,
  ),
  Category(
    id: 'salary',
    name: 'Salary',
    icon: 'salary',
    color: 0xFF12B886,
    type: TxType.income,
    builtin: true,
    sort: 20,
  ),
  Category(
    id: 'business',
    name: 'Business',
    icon: 'business',
    color: 0xFF0984E3,
    type: TxType.income,
    builtin: true,
    sort: 21,
  ),
  Category(
    id: 'freelance',
    name: 'Freelance',
    icon: 'laptop',
    color: 0xFF6C5CE7,
    type: TxType.income,
    builtin: true,
    sort: 22,
  ),
  Category(
    id: 'investment',
    name: 'Investments',
    icon: 'invest',
    color: 0xFF2E9E5B,
    type: TxType.income,
    builtin: true,
    sort: 23,
  ),
  Category(
    id: 'gift_in',
    name: 'Gifts received',
    icon: 'redeem',
    color: 0xFFE84393,
    type: TxType.income,
    builtin: true,
    sort: 24,
  ),
  Category(
    id: 'other_inc',
    name: 'Other income',
    icon: 'wallet',
    color: 0xFF90A4AE,
    type: TxType.income,
    builtin: true,
    sort: 25,
  ),
];

class Txn {
  const Txn({
    this.id,
    required this.date,
    required this.amountMinor,
    required this.type,
    required this.categoryId,
    this.accountId = kDefaultAccountId,
    this.note = '',
    required this.createdAt,
  });

  final int? id;
  final DateTime date; // local transaction date and time
  final int amountMinor; // always positive
  final TxType type;
  final String categoryId;
  final String accountId;
  final String note;
  final int createdAt; // epoch millis

  bool get isIncome => type == TxType.income;
  int get signed => isIncome ? amountMinor : -amountMinor;

  Txn copyWith({
    int? id,
    DateTime? date,
    int? amountMinor,
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
    'amount_minor': amountMinor,
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
    amountMinor: (m['amount_minor'] as num).toInt(),
    type: (m['type'] as num).toInt() == 1 ? TxType.income : TxType.expense,
    categoryId: m['category_id'] as String,
    note: (m['note'] as String?) ?? '',
    createdAt: (m['created_at'] as num).toInt(),
  );
}

class Totals {
  const Totals(this.income, this.expense);
  final int income;
  final int expense;
  static const Totals zero = Totals(0, 0);

  int get net => income - expense;
  bool get isEmpty => income == 0 && expense == 0;

  Totals operator +(Totals o) => Totals(income + o.income, expense + o.expense);
}
