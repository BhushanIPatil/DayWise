import 'fixtures/legacy_categories.dart';
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

  for (final version in [1, 2, 3]) {
    test('v$version migration preserves entries, categories and recurring markers', () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: (raw, _) async {
            await raw.execute(
              'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, amount_minor INTEGER NOT NULL, type INTEGER NOT NULL, category_id TEXT NOT NULL, note TEXT NOT NULL, created_at INTEGER NOT NULL)',
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
            if (version >= 2) {
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
            if (version == 3) {
              await raw.execute(
                'CREATE TABLE accounts(id TEXT PRIMARY KEY, name TEXT NOT NULL, opening_balance_minor INTEGER NOT NULL DEFAULT 0, color INTEGER NOT NULL)',
              );
              await raw.insert('accounts', {
                ...kDefaultAccount.toMap(),
                'opening_balance_minor': 321,
              });
              await raw.execute(
                "ALTER TABLE transactions ADD COLUMN account_id TEXT NOT NULL DEFAULT '$kDefaultAccountId'",
              );
              await raw.execute(
                'ALTER TABLE transactions ADD COLUMN occurred_at TEXT',
              );
              await raw.execute(
                "ALTER TABLE recurring ADD COLUMN account_id TEXT NOT NULL DEFAULT '$kDefaultAccountId'",
              );
              await raw.execute(
                'ALTER TABLE recurring ADD COLUMN time_minutes INTEGER NOT NULL DEFAULT 0',
              );
              await raw.execute(
                'CREATE INDEX idx_tx_date ON transactions(date)',
              );
              await raw.execute(
                'CREATE INDEX idx_tx_account_date ON transactions(account_id, date)',
              );
            }
            await raw.execute(
              'INSERT INTO transactions(id, date, amount_minor, type, category_id, note, created_at) SELECT 100, date, amount_minor, type, category_id, note, created_at FROM transactions WHERE id = 42',
            );
            await raw.delete('transactions', where: 'id = 100');
          },
        ),
      );
      await legacy.close();
      final entries = await db.allTxns();
      expect(entries.single.id, 42);
      expect(entries.single.note, 'Keep me');
      expect(entries.single.categoryId, kDefaultCategoryId);
      expect(entries.single.amountMinor, BigInt.from(12345));
      expect(entries.single.accountId, kDefaultAccountId);
      expect(entries.single.date, DateTime(2026, 10, 1));
      expect((await db.accounts()).single.name, 'Everyday');
      expect((await db.categories()).any((c) => c.id == 'custom'), true);
      final rules = await db.rules();
      if (version >= 2) {
        expect(rules.single.lastGenerated, DateTime(2026, 10, 1));
        expect(rules.single.accountId, kDefaultAccountId);
        expect(rules.single.categoryId, kDefaultCategoryId);
      } else {
        expect(rules, isEmpty);
      }
      expect(
        (await db.accounts()).single.openingBalanceMinor,
        BigInt.from(version == 3 ? 321 : 0),
      );
      final insertedId = await db.upsertTxn(
        entry(kDefaultAccountId, DateTime(2026, 11, 24), 100, TxType.income),
      );
      expect(insertedId, 101);
    });
  }

  test(
    'text amounts retain exact values across SQLite, balances, JSON and CSV',
    () async {
      final amount = BigInt.parse('123456789012345678901234567890123456789');
      await db.upsertAccount(
        MoneyAccount(
          id: 'large',
          name: 'Large amounts',
          openingBalanceMinor: amount,
        ),
      );
      await db.upsertTxn(
        Txn(
          date: DateTime(2026, 11, 24, 12),
          accountId: 'large',
          amountMinor: amount,
          type: TxType.income,
          createdAt: 1,
        ),
      );
      await db.upsertTxn(
        Txn(
          date: DateTime(2026, 11, 24, 13),
          accountId: 'large',
          amountMinor: 17,
          type: TxType.expense,
          createdAt: 2,
        ),
      );
      await db.upsertRule(
        RecurringRule(
          type: TxType.income,
          amountMinor: amount,
          frequency: Frequency.monthly,
          startDate: DateTime(2090),
          createdAt: 1,
        ),
      );
      await db.close();
      await state.load();
      expect(state.all.singleWhere((txn) => txn.isIncome).amountMinor, amount);
      expect(
        state.accountBalance('large'),
        amount * BigInt.two - BigInt.from(17),
      );
      expect(state.rules.single.amountMinor, amount);
      final restored = parseBackup(state.buildBackupJson());
      expect(
        restored.txns.singleWhere((txn) => txn.isIncome).amountMinor,
        amount,
      );
      expect(restored.rules.single.amountMinor, amount);
      expect(state.buildBackupJson(), contains('"amountMinor": "$amount"'));
      expect(state.buildCsv(), contains(minorToPlain(amount)));
      expect(
        state.buildCsv(),
        contains(minorToPlain(amount * BigInt.two - BigInt.from(17))),
      );
      final raw = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        expect(
          (await raw.rawQuery(
            'SELECT typeof(amount_minor) AS kind FROM transactions',
          )).every((row) => row['kind'] == 'text'),
          isTrue,
        );
        expect(
          (await raw.rawQuery(
            'SELECT typeof(amount_minor) AS kind FROM recurring',
          )).single['kind'],
          'text',
        );
        expect(
          (await raw.rawQuery(
            "SELECT typeof(opening_balance_minor) AS kind FROM accounts WHERE id = 'large'",
          )).single['kind'],
          'text',
        );
      } finally {
        await raw.close();
      }
    },
  );

  test(
    'account deletion removes only its data and preserves a usable account',
    () async {
      await state.load();
      await state.saveAccount(
        const MoneyAccount(
          id: 'bank',
          name: 'Savings',
          openingBalanceMinor: 10000,
        ),
      );
      final date = DateTime(2026, 11, 5);
      await state.addTxn(entry(kDefaultAccountId, date, 1200, TxType.expense));
      await state.addTxn(entry('bank', date, 5000, TxType.income));
      for (final id in [kDefaultAccountId, 'bank']) {
        await db.upsertRule(
          RecurringRule(
            type: TxType.income,
            amountMinor: 1000,
            accountId: id,
            frequency: Frequency.daily,
            startDate: DateTime(2090),
            createdAt: 1,
          ),
        );
      }
      await state.load();
      state.selectAccount(kDefaultAccountId);
      await state.deleteAccount(kDefaultAccountId);
      expect(state.accounts.single.id, 'bank');
      expect(state.defaultAccount.id, 'bank');
      expect(state.selectedAccountId, isNull);
      expect(state.all.single.accountId, 'bank');
      expect(state.rules.single.accountId, 'bank');
      expect(state.dayTotals(date).income, BigInt.from(5000));
      expect(state.dayTotals(date).expense, BigInt.from(0));
      expect(state.accountBalance('bank'), BigInt.from(15000));
      expect((await db.allTxns()).single.accountId, 'bank');
      expect((await db.rules()).single.accountId, 'bank');
      expect(parseBackup(state.buildBackupJson()).accounts.single.id, 'bank');
      await state.load();
      expect(state.accounts.single.id, 'bank');
      await expectLater(state.deleteAccount('bank'), throwsStateError);
      expect((await db.accounts()).single.id, 'bank');
      expect((await db.allTxns()).single.accountId, 'bank');
      expect((await db.rules()).single.accountId, 'bank');
    },
  );

  test(
    'new account opening balance is dated income without double counting',
    () async {
      await state.load();
      final date = DateTime(2026, 11, 5, 18, 42);
      final account = await state.createAccount(
        const MoneyAccount(
          id: 'new-bank',
          name: 'New savings',
          openingBalanceMinor: 500000,
        ),
        openingDate: date,
      );
      expect(account.openingBalanceMinor, BigInt.from(0));
      final opening = state.transactionsForAccount(account.id).single;
      expect(opening.note, 'Opening balance');
      expect(opening.type, TxType.income);
      expect(opening.amountMinor, BigInt.from(500000));
      expect(opening.date, date);
      expect(state.accountBalance(account.id), BigInt.from(500000));
      expect(state.accountTotals(account.id).income, BigInt.from(500000));
      expect(state.dayTotals(date).income, BigInt.from(500000));
      expect(state.balanceAfter(opening), BigInt.from(500000));
      await state.saveAccount(
        const MoneyAccount(id: 'new-bank', name: 'Renamed savings'),
      );
      await state.load();
      expect(state.transactionsForAccount(account.id), hasLength(1));
      expect(state.accountBalance(account.id), BigInt.from(500000));
      final restored = parseBackup(state.buildBackupJson());
      expect(
        restored.accounts
            .firstWhere((a) => a.id == account.id)
            .openingBalanceMinor,
        BigInt.from(0),
      );
      expect(restored.txns.single.date, date);
      await state.updateTxn(state.all.single.copyWith(amountMinor: 400000));
      expect(state.accountBalance(account.id), BigInt.from(400000));
      await state.deleteTxn(state.all.single);
      expect(state.accountBalance(account.id), BigInt.from(0));
    },
  );

  test(
    'zero opening creates no record and negative opening is an expense',
    () async {
      await state.load();
      final date = DateTime(2026, 11, 5, 10, 15);
      await state.createAccount(
        const MoneyAccount(id: 'empty', name: 'Empty'),
        openingDate: date,
      );
      expect(state.transactionsForAccount('empty'), isEmpty);
      await state.createAccount(
        const MoneyAccount(
          id: 'debt',
          name: 'Credit',
          openingBalanceMinor: -12000,
        ),
        openingDate: date,
      );
      final opening = state.transactionsForAccount('debt').single;
      expect(opening.type, TxType.expense);
      expect(opening.amountMinor, BigInt.from(12000));
      expect(state.accountBalance('debt'), BigInt.from(-12000));
      expect(state.accountById('debt').openingBalanceMinor, BigInt.from(0));
    },
  );

  test('failed opening record insertion rolls back account creation', () async {
    await state.load();
    final inspector = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      await inspector.execute(
        "CREATE TRIGGER reject_opening BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        state.createAccount(
          const MoneyAccount(
            id: 'failed',
            name: 'Failed',
            openingBalanceMinor: 1000,
          ),
          openingDate: DateTime(2026),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        (await db.accounts()).any((account) => account.id == 'failed'),
        isFalse,
      );
      expect(await db.allTxns(), isEmpty);
      expect(state.accounts.any((account) => account.id == 'failed'), isFalse);
    } finally {
      await inspector.close();
    }
  });

  test(
    'account budgets persist, aggregate, restore and delete independently',
    () async {
      await state.load();
      await state.saveAccount(const MoneyAccount(id: 'bank', name: 'Savings'));
      state.setMonthlyBudget(10000, accountId: kDefaultAccountId);
      state.setDailyBudget(1000, accountId: kDefaultAccountId);
      state.setMonthlyBudget(20000, accountId: 'bank');
      state.setDailyBudget(2000, accountId: 'bank');
      expect(state.monthlyBudgetMinor, 30000);
      expect(state.dailyBudgetMinor, 3000);
      state.selectAccount('bank');
      expect(state.monthlyBudgetMinor, 20000);
      expect(state.dailyBudgetMinor, 2000);
      state.setMonthlyBudget(25000);
      state.setDailyBudget(0);
      await state.load();
      expect(state.monthlyBudgetMinor, 25000);
      expect(state.dailyBudgetMinor, 0);
      expect(state.budgetForAccount(kDefaultAccountId).dailyMinor, 1000);
      final backup = parseBackup(state.buildBackupJson());
      state.setMonthlyBudget(0);
      await state.importBackup(backup, replace: true);
      expect(state.budgetForAccount('bank').monthlyMinor, 25000);
      expect(state.budgetForAccount(kDefaultAccountId).monthlyMinor, 10000);
      await state.deleteAccount('bank');
      expect(state.accountBudgets.containsKey('bank'), isFalse);
      expect(state.monthlyBudgetMinor, 10000);
      await state.deleteAllData();
      await state.load();
      expect(state.monthlyBudgetMinor, 0);
      expect(state.dailyBudgetMinor, 0);
    },
  );

  test('old global budgets migrate once to the default account', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('monthlyBudget', 30000);
    await prefs.setInt('dailyBudget', 2000);
    await state.load();
    expect(state.budgetForAccount(kDefaultAccountId).monthlyMinor, 30000);
    await state.saveAccount(const MoneyAccount(id: 'bank', name: 'Savings'));
    state.selectAccount('bank');
    expect(state.monthlyBudgetMinor, 0);
    state.setMonthlyBudget(0, accountId: kDefaultAccountId);
    await state.load();
    expect(state.budgetForAccount(kDefaultAccountId).monthlyMinor, 0);
    expect(state.budgetForAccount(kDefaultAccountId).dailyMinor, 2000);
  });

  test(
    'editing and deleting a recurring rule preserves recorded history',
    () async {
      await state.load();
      await state.saveAccount(const MoneyAccount(id: 'bank', name: 'Savings'));
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final original = await state.addTxn(
        entry(kDefaultAccountId, today, 1000, TxType.expense),
      );
      final id = await db.upsertRule(
        RecurringRule(
          type: TxType.expense,
          amountMinor: 1000,
          note: 'Old rent',
          frequency: Frequency.daily,
          startDate: DateTime(2020),
          lastGenerated: today,
          createdAt: 1,
        ),
      );
      await state.load();
      await state.updateRule(
        RecurringRule(
          id: id,
          type: TxType.income,
          amountMinor: 2000,
          accountId: 'bank',
          timeMinutes: 15 * 60 + 45,
          note: 'New salary',
          frequency: Frequency.daily,
          startDate: DateTime(2000),
          createdAt: 1,
        ),
      );
      expect(state.rules, hasLength(1));
      expect(state.rules.single.accountId, 'bank');
      expect(state.rules.single.amountMinor, BigInt.from(2000));
      expect(state.rules.single.lastGenerated, today);
      expect(state.all.single.id, original.id);
      expect(state.all.single.amountMinor, BigInt.from(1000));
      expect(state.all.single.type, TxType.expense);
      expect(state.upcomingRecurring().first.rule.note, 'New salary');
      await state.deleteRule(state.rules.single);
      expect(state.rules, isEmpty);
      expect(state.all.single.id, original.id);
    },
  );

  test(
    'running balances include prior history, use stable transaction order, and follow edits',
    () async {
      await state.load();
      await state.saveAccount(
        const MoneyAccount(
          id: 'bank',
          name: 'Savings',
          openingBalanceMinor: 10000,
        ),
      );
      final older = await state.addTxn(
        entry('bank', DateTime(2026, 1, 31), 5000, TxType.income),
      );
      final expense = await state.addTxn(
        entry('bank', DateTime(2026, 2, 1, 10), 2000, TxType.expense),
      );
      final income = await state.addTxn(
        entry('bank', expense.date, 1000, TxType.income),
      );
      final other = await state.addTxn(
        entry(kDefaultAccountId, DateTime(2026, 2, 1, 11), 900, TxType.expense),
      );
      expect(state.balanceAfter(older), BigInt.from(15000));
      expect(state.balanceAfter(expense), BigInt.from(13000));
      expect(state.balanceAfter(income), BigInt.from(14000));
      expect(state.balanceAfter(other), BigInt.from(-900));
      state.selectAccount('bank');
      final filtered = state.recordsInRange(
        DateTime(2026, 2),
        DateTime(2026, 2, 28),
      );
      expect(filtered, hasLength(2));
      expect(state.balanceAfter(filtered.last), BigInt.from(13000));
      await state.updateTxn(older.copyWith(amountMinor: 8000));
      expect(state.balanceAfter(expense), BigInt.from(16000));
      expect(state.balanceAfter(income), BigInt.from(17000));
      await state.deleteTxn(expense);
      expect(state.balanceAfter(income), BigInt.from(19000));
      await state.updateTxn(income.copyWith(accountId: kDefaultAccountId));
      expect(state.balanceAfter(other), BigInt.from(100));
      expect(state.accountBalance('bank'), BigInt.from(18000));
      await state.load();
      expect(
        state.balanceAfter(state.all.firstWhere((txn) => txn.id == other.id)),
        BigInt.from(100),
      );
    },
  );

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
      expect(state.accountBalance('bank'), BigInt.from(13800));
      expect(state.accountBalance(kDefaultAccountId), BigInt.from(-700));
      expect(state.dayTotals(date).expense, BigInt.from(1900));
      state.selectAccount('bank');
      expect(state.dayTotals(date).expense, BigInt.from(1200));
      expect(state.monthTotals(2026, 11).income, BigInt.from(5000));
      expect(state.search('Savings').length, 2);
      expect(state.forDay(date).first.id, income.id);
      expect(state.rangeTotals(date, date).expense, BigInt.from(1200));
      await state.updateTxn(income.copyWith(accountId: kDefaultAccountId));
      expect(state.dayTotals(date).income, BigInt.from(0));
      expect(state.accountBalance('bank'), BigInt.from(8800));
      expect(state.accountBalance(kDefaultAccountId), BigInt.from(4300));
      expect(
        (await db.allTxns()).firstWhere((t) => t.id == income.id).date,
        date,
      );
      state.selectAccount(null);
      expect(state.dayTotals(date).income, BigInt.from(5000));
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
      expect(state.accountBalance('bank'), BigInt.from(8500));
      expect(state.accounts.length, 2);
      await state.deleteAllData();
      expect(state.all, isEmpty);
      expect(state.accounts.single.id, kDefaultAccountId);
      expect(state.selectedAccountId, isNull);
      expect(state.accountBalance(kDefaultAccountId), BigInt.from(0));
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
