import 'dart:convert';
import 'dart:io';

import 'package:daywise/data/backup.dart';
import 'package:daywise/data/database_backup.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('daywise_backup_'),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'SQLite backup preserves accounts, timestamps, rules and budgets',
    () async {
      final path = '${directory.path}/backup.db';
      final occurred = DateTime(2026, 11, 10, 14, 35);
      final data = ParsedBackup(
        txns: [
          Txn(
            date: occurred,
            amountMinor: 12450,
            type: TxType.expense,
            categoryId: 'food',
            accountId: 'bank',
            note: 'Lunch, with friends',
            createdAt: 123,
          ),
        ],
        categories: kDefaultCategories,
        accounts: [
          kDefaultAccount,
          const MoneyAccount(
            id: 'bank',
            name: 'Savings',
            openingBalanceMinor: 500000,
          ),
        ],
        rules: [
          RecurringRule(
            type: TxType.income,
            amountMinor: 100000,
            categoryId: 'salary',
            accountId: 'bank',
            timeMinutes: 540,
            note: 'Salary',
            frequency: Frequency.monthly,
            startDate: DateTime(2026, 11, 1),
            lastGenerated: DateTime(2026, 11, 1),
            createdAt: 1,
          ),
        ],
        skipped: 0,
        currency: 'USD',
        monthlyBudgetMinor: 100000,
        dailyBudgetMinor: 20000,
      );
      await DatabaseBackup.write(path, data, factory: databaseFactoryFfi);
      final bytes = await File(path).readAsBytes();
      expect(ascii.decode(bytes.take(16).toList()), 'SQLite format 3\u0000');
      final restored = await DatabaseBackup.read(
        path,
        factory: databaseFactoryFfi,
      );
      expect(restored.txns.single.date, occurred);
      expect(restored.txns.single.amountMinor, 12450);
      expect(restored.txns.single.note, 'Lunch, with friends');
      expect(restored.txns.single.accountId, 'bank');
      expect(restored.txns.single.createdAt, 123);
      expect(restored.accounts.last.openingBalanceMinor, 500000);
      expect(restored.rules.single.timeMinutes, 540);
      expect(restored.rules.single.lastGenerated, DateTime(2026, 11, 1));
      expect(restored.currency, 'USD');
      expect(restored.monthlyBudgetMinor, 100000);
      expect(restored.dailyBudgetMinor, 20000);
    },
  );

  test('rejects unrelated SQLite files without changing them', () async {
    final path = '${directory.path}/other.db';
    final db = await databaseFactoryFfi.openDatabase(path);
    await db.execute('CREATE TABLE unrelated(value TEXT)');
    await db.close();
    final original = await File(path).readAsBytes();
    await expectLater(
      DatabaseBackup.read(path, factory: databaseFactoryFfi),
      throwsFormatException,
    );
    expect(await File(path).readAsBytes(), original);
  });
}
