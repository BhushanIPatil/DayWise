import 'dart:convert';

import '../core/format.dart';
import 'models.dart';
import 'recurrence.dart';

/// Pure (no I/O) helpers for the backup file and CSV export, so they can be unit tested.

const String kBackupApp = 'DayWise';
const int kBackupSchema = 2;

class ParsedBackup {
  ParsedBackup({
    required this.txns,
    required this.categories,
    required this.skipped,
    this.rules = const [],
    this.accounts = const [kDefaultAccount],
    this.currency,
    this.monthlyBudgetMinor,
    this.dailyBudgetMinor,
  });

  final List<Txn> txns;
  final List<Category> categories;
  final List<RecurringRule> rules;
  final List<MoneyAccount> accounts;

  /// Rows in the file that were invalid and ignored.
  final int skipped;
  final String? currency;
  final int? monthlyBudgetMinor;
  final int? dailyBudgetMinor;
}

String encodeBackup({
  required List<Txn> txns,
  required List<Category> categories,
  required String currency,
  required int monthlyBudgetMinor,
  required int dailyBudgetMinor,
  List<RecurringRule> rules = const [],
  List<MoneyAccount> accounts = const [kDefaultAccount],
  DateTime? now,
}) {
  final data = <String, Object?>{
    'app': kBackupApp,
    'schema': kBackupSchema,
    'exportedAt': (now ?? DateTime.now()).toIso8601String(),
    'settings': {
      'currency': currency,
      'monthlyBudgetMinor': monthlyBudgetMinor,
      'dailyBudgetMinor': dailyBudgetMinor,
    },
    'accounts': [for (final account in accounts) account.toMap()],
    'categories': [
      for (final c in categories)
        {
          'id': c.id,
          'name': c.name,
          'icon': c.icon,
          'color': c.color,
          'type': c.type == TxType.income ? 'income' : 'expense',
          'builtin': c.builtin,
        },
    ],
    'recurring': [
      for (final r in rules)
        {
          'type': r.type == TxType.income ? 'income' : 'expense',
          'amountMinor': r.amountMinor,
          'categoryId': r.categoryId,
          'accountId': r.accountId,
          'timeMinutes': r.timeMinutes,
          'note': r.note,
          'frequency': r.frequency.name,
          'startDate': dateKey(r.startDate),
          'endDate': r.endDate == null ? null : dateKey(r.endDate!),
          'lastGenerated': r.lastGenerated == null
              ? null
              : dateKey(r.lastGenerated!),
        },
    ],
    'transactions': [
      for (final t in txns)
        {
          'date': dateKey(t.date),
          'occurredAt': t.date.toIso8601String(),
          'accountId': t.accountId,
          'amountMinor': t.amountMinor,
          'type': t.isIncome ? 'income' : 'expense',
          'categoryId': t.categoryId,
          'note': t.note,
          'createdAt': t.createdAt,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

/// Throws [FormatException] when the text is not a DayWise backup.
ParsedBackup parseBackup(String text) {
  final dynamic root;
  try {
    root = jsonDecode(text);
  } catch (_) {
    throw const FormatException('This file is not valid JSON.');
  }
  if (root is! Map ||
      root['app'] != kBackupApp ||
      root['transactions'] is! List) {
    throw const FormatException('This is not a DayWise backup file.');
  }
  final schema = root['schema'];
  if (schema is! num || schema.toInt() > kBackupSchema) {
    throw const FormatException(
      'This backup was made by a newer version of DayWise. Please update the app.',
    );
  }

  var skipped = 0;
  final txns = <Txn>[];
  for (final raw in root['transactions'] as List) {
    try {
      final m = raw as Map;
      final amount = (m['amountMinor'] as num).toInt();
      if (amount <= 0) throw const FormatException('amount');
      txns.add(
        Txn(
          date: m['occurredAt'] == null
              ? parseKey(m['date'] as String)
              : DateTime.parse(m['occurredAt'] as String),
          accountId: (m['accountId'] as String?) ?? kDefaultAccountId,
          amountMinor: amount,
          type: m['type'] == 'income' ? TxType.income : TxType.expense,
          categoryId: (m['categoryId'] as String?) ?? kUncategorised.id,
          note: (m['note'] as String?) ?? '',
          createdAt:
              (m['createdAt'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      skipped++;
    }
  }

  final cats = <Category>[];
  final rawCats = root['categories'];
  if (rawCats is List) {
    for (final raw in rawCats) {
      try {
        final m = raw as Map;
        cats.add(
          Category(
            id: m['id'] as String,
            name: m['name'] as String,
            icon: (m['icon'] as String?) ?? 'other',
            color: (m['color'] as num).toInt(),
            type: m['type'] == 'income' ? TxType.income : TxType.expense,
            builtin: m['builtin'] == true,
            sort: 1000 + cats.length,
          ),
        );
      } catch (_) {
        // ignore a bad category row
      }
    }
  }

  final rules = <RecurringRule>[];
  final rawRules = root['recurring'];
  if (rawRules is List) {
    for (final raw in rawRules) {
      try {
        final m = raw as Map;
        final amount = (m['amountMinor'] as num).toInt();
        if (amount <= 0) throw const FormatException('amount');
        rules.add(
          RecurringRule(
            type: m['type'] == 'income' ? TxType.income : TxType.expense,
            amountMinor: amount,
            categoryId: (m['categoryId'] as String?) ?? kUncategorised.id,
            accountId: (m['accountId'] as String?) ?? kDefaultAccountId,
            timeMinutes: ((m['timeMinutes'] as num?)?.toInt() ?? 0).clamp(
              0,
              1439,
            ),
            note: (m['note'] as String?) ?? '',
            frequency: Frequency.values.firstWhere(
              (f) => f.name == m['frequency'],
              orElse: () => Frequency.monthly,
            ),
            startDate: parseKey(m['startDate'] as String),
            endDate: m['endDate'] == null
                ? null
                : parseKey(m['endDate'] as String),
            lastGenerated: m['lastGenerated'] == null
                ? null
                : parseKey(m['lastGenerated'] as String),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (_) {
        skipped++;
      }
    }
  }

  final accounts = <String, MoneyAccount>{};
  final rawAccounts = root['accounts'];
  if (rawAccounts is List) {
    for (final raw in rawAccounts) {
      try {
        final account = MoneyAccount.fromMap(
          Map<String, Object?>.from(raw as Map),
        );
        if (account.id.trim().isEmpty || account.name.trim().isEmpty) continue;
        accounts[account.id] = account;
      } catch (_) {
        skipped++;
      }
    }
  }
  // Keep legacy data and recover account references if a backup omitted a row.
  for (final id in {
    kDefaultAccountId,
    ...txns.map((t) => t.accountId),
    ...rules.map((r) => r.accountId),
  }) {
    accounts.putIfAbsent(
      id,
      () => id == kDefaultAccountId
          ? kDefaultAccount
          : MoneyAccount(
              id: id,
              name: 'Restored account ${accounts.length + 1}',
            ),
    );
  }

  String? currency;
  int? monthly;
  int? daily;
  final st = root['settings'];
  if (st is Map) {
    if (st['currency'] is String) currency = st['currency'] as String;
    if (st['monthlyBudgetMinor'] is num) {
      monthly = (st['monthlyBudgetMinor'] as num).toInt();
    }
    if (st['dailyBudgetMinor'] is num) {
      daily = (st['dailyBudgetMinor'] as num).toInt();
    }
  }

  return ParsedBackup(
    txns: txns,
    categories: cats,
    rules: rules,
    accounts: accounts.values.toList(),
    skipped: skipped,
    currency: currency,
    monthlyBudgetMinor: monthly,
    dailyBudgetMinor: daily,
  );
}

String _csvCell(String s) {
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// "12345" -> "123.45"
String minorToPlain(int minor) {
  final a = minor.abs();
  return '${a ~/ 100}.${two(a % 100)}';
}

String encodeCsv(
  List<Txn> txns,
  String Function(String id) categoryName, {
  String Function(String id)? accountName,
}) {
  final sorted = [...txns]
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  final sb = StringBuffer('Date,Time,Account,Type,Category,Amount,Note\r\n');
  for (final t in sorted) {
    sb.write(
      '${dateKey(t.date)},${two(t.date.hour)}:${two(t.date.minute)},'
      '${_csvCell(accountName?.call(t.accountId) ?? t.accountId)},${t.isIncome ? 'Income' : 'Expense'},'
      '${_csvCell(categoryName(t.categoryId))},${minorToPlain(t.amountMinor)},${_csvCell(t.note)}\r\n',
    );
  }
  return sb.toString();
}
