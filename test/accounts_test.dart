import 'dart:io';

import 'package:daywise/data/backup.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late AppDb db;
  late AppState state;
  late String path;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('daywise_accounts_');
    path = '${directory.path}/daywise.db';
    db = AppDb(factory: databaseFactoryFfi, path: path);
    SharedPreferences.setMockInitialValues({});
    state = AppState(db, await SharedPreferences.getInstance());
  });
  tearDown(() async {
    state.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  Txn entry(String accountId, DateTime date, int amount, TxType type) => Txn(
    accountId: accountId,
    date: date,
    amountMinor: amount,
    type: type,
    categoryId: type == TxType.income ? 'salary' : 'food',
    createdAt: 1,
  );

  for (final version in [1, 2]) {
    test(
      'v$version migration preserves entries, categories and recurring markers',
      () async {
        final legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: (raw, _) async {
              await raw.execute(
                'CREATE TABLE transactions(id INTEGER PRIMARY KEY, date TEXT NOT NULL, amount_minor INTEGER NOT NULL, type INTEGER NOT NULL, category_id TEXT NOT NULL, note TEXT NOT NULL, created_at INTEGER NOT NULL)',
              );
              await raw.execute(
                'CREATE TABLE categories(id TEXT PRIMARY KEY, name TEXT NOT NULL, icon TEXT NOT NULL, color INTEGER NOT NULL, type INTEGER NOT NULL, builtin INTEGER NOT NULL, sort INTEGER NOT NULL)',
              );
              await raw.insert('transactions', {
                'id': 42,
                'date': '2026-10-01',
                'amount_minor': 12345,
                'type': 0,
                'category_id': 'custom',
                'note': 'Keep me',
                'created_at': 123,
              });
              await raw.insert(
                'categories',
                const Category(
                  id: 'custom',
                  name: 'My category',
                  icon: 'other',
                  color: 0xFF6C5CE7,
                  type: TxType.expense,
                ).toMap(),
              );
              if (version == 2) {
                await raw.execute(
                  'CREATE TABLE recurring(id INTEGER PRIMARY KEY, type INTEGER NOT NULL, amount_minor INTEGER NOT NULL, category_id TEXT NOT NULL, note TEXT NOT NULL, frequency INTEGER NOT NULL, start_date TEXT NOT NULL, end_date TEXT, last_generated TEXT, created_at INTEGER NOT NULL)',
                );
                await raw.insert('recurring', {
                  'id': 7,
                  'type': 0,
                  'amount_minor': 1000,
                  'category_id': 'custom',
                  'note': 'Rent',
                  'frequency': 2,
                  'start_date': '2026-01-01',
                  'last_generated': '2026-10-01',
                  'created_at': 1,
                });
              }
            },
          ),
        );
        await legacy.close();
        final entries = await db.allTxns();
        expect(entries.single.id, 42);
        expect(entries.single.note, 'Keep me');
        expect(entries.single.amountMinor, 12345);
        expect(entries.single.accountId, kDefaultAccountId);
        expect(entries.single.date, DateTime(2026, 10, 1));
        expect((await db.accounts()).single.name, 'Everyday');
        expect((await db.categories()).any((c) => c.id == 'custom'), true);
        final rules = await db.rules();
        if (version == 2) {
          expect(rules.single.lastGenerated, DateTime(2026, 10, 1));
          expect(rules.single.accountId, kDefaultAccountId);
        } else {
          expect(rules, isEmpty);
        }
      },
    );
  }

  test(
    'account balances, filters, chronological order and moving entries stay consistent',
    () async {
      await state.load();
      await state.saveAccount(
        const MoneyAccount(
          id: 'bank',
          name: 'Savings',
          openingBalanceMinor: 10000,
        ),
      );
      final date = DateTime(2026, 11, 5, 12, 30);
      final income = await state.addTxn(
        entry('bank', date, 5000, TxType.income),
      );
      await state.addTxn(
        entry('bank', DateTime(2026, 11, 5, 9), 1200, TxType.expense),
      );
      await state.addTxn(entry(kDefaultAccountId, date, 700, TxType.expense));
      expect(state.accountBalance('bank'), 13800);
      expect(state.accountBalance(kDefaultAccountId), -700);
      expect(state.dayTotals(date).expense, 1900);
      state.selectAccount('bank');
      expect(state.dayTotals(date).expense, 1200);
      expect(state.monthTotals(2026, 11).income, 5000);
      expect(state.search('Savings').length, 2);
      expect(state.forDay(date).first.id, income.id);
      expect(state.expenseByCategory(date, date).single.value, 1200);
      await state.updateTxn(income.copyWith(accountId: kDefaultAccountId));
      expect(state.dayTotals(date).income, 0);
      expect(state.accountBalance('bank'), 8800);
      expect(state.accountBalance(kDefaultAccountId), 4300);
      expect(
        (await db.allTxns()).firstWhere((t) => t.id == income.id).date,
        date,
      );
      state.selectAccount(null);
      expect(state.dayTotals(date).income, 5000);
    },
  );

  test(
    'merge distinguishes accounts and times, replace and delete reset account state',
    () async {
      await state.load();
      await state.saveAccount(
        const MoneyAccount(
          id: 'bank',
          name: 'Second bank',
          openingBalanceMinor: 9000,
        ),
      );
      final original = entry(
        kDefaultAccountId,
        DateTime(2026, 11, 5, 10),
        500,
        TxType.expense,
      );
      await state.addTxn(original);
      final backup = parseBackup(
        encodeBackup(
          txns: [
            original,
            original.copyWith(accountId: 'bank'),
            original.copyWith(date: DateTime(2026, 11, 5, 11)),
          ],
          categories: kDefaultCategories,
          accounts: state.accounts,
          currency: 'INR',
          monthlyBudgetMinor: 0,
          dailyBudgetMinor: 0,
        ),
      );
      final merged = await state.importBackup(backup, replace: false);
      expect(merged.added, 2);
      expect(merged.duplicates, 1);
      expect(state.all.length, 3);
      state.selectAccount('bank');
      await state.importBackup(backup, replace: true);
      expect(state.accountBalance('bank'), 8500);
      expect(state.accounts.length, 2);
      await state.deleteAllData();
      expect(state.all, isEmpty);
      expect(state.accounts.single.id, kDefaultAccountId);
      expect(state.selectedAccountId, isNull);
      expect(state.accountBalance(kDefaultAccountId), 0);
    },
  );

  test(
    'recurring entries keep account and time and wait until their scheduled time',
    () async {
      await state.load();
      await state.saveAccount(const MoneyAccount(id: 'bank', name: 'Savings'));
      // Insert without triggering wall-clock generation so the due time is deterministic.
      await db.upsertRule(
        RecurringRule(
          type: TxType.income,
          amountMinor: 50000,
          accountId: 'bank',
          timeMinutes: 15 * 60 + 45,
          categoryId: 'salary',
          frequency: Frequency.daily,
          startDate: DateTime(2090, 1, 1),
          createdAt: 1,
        ),
      );
      await state.load();
      expect(await state.generateDue(at: DateTime(2090, 1, 1, 15, 44)), 0);
      expect(await state.generateDue(at: DateTime(2090, 1, 1, 15, 45)), 1);
      expect(state.all.single.accountId, 'bank');
      expect(state.all.single.date, DateTime(2090, 1, 1, 15, 45));
      expect(await state.generateDue(at: DateTime(2090, 1, 1, 18)), 0);
    },
  );
}
