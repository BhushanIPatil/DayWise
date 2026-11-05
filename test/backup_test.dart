import 'package:daywise/data/backup.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final txns = [
    Txn(
      id: 1,
      date: DateTime(2026, 10, 1),
      amountMinor: 12050,
      type: TxType.expense,
      categoryId: 'food',
      note: 'Lunch, with "friends"',
      createdAt: 1,
    ),
    Txn(
      id: 2,
      date: DateTime(2026, 10, 2),
      amountMinor: 5000000,
      type: TxType.income,
      categoryId: 'salary',
      createdAt: 2,
    ),
  ];

  test('backup round trip', () {
    final json = encodeBackup(
      txns: txns,
      categories: kDefaultCategories,
      currency: 'INR',
      monthlyBudgetMinor: 3000000,
      dailyBudgetMinor: 100000,
    );
    final p = parseBackup(json);
    expect(p.txns.length, 2);
    expect(p.skipped, 0);
    expect(p.txns[0].note, 'Lunch, with "friends"');
    expect(p.txns[0].amountMinor, 12050);
    expect(p.txns[1].isIncome, true);
    expect(p.categories.length, kDefaultCategories.length);
    expect(p.currency, 'INR');
    expect(p.monthlyBudgetMinor, 3000000);
  });

  test('recurring rules survive a round trip', () {
    final rule = RecurringRule(
      type: TxType.expense,
      amountMinor: 1500000,
      categoryId: 'rent',
      note: 'Rent',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 1),
      lastGenerated: DateTime(2026, 3, 1),
      createdAt: 1,
    );
    final json = encodeBackup(
      txns: txns,
      categories: const [],
      currency: 'INR',
      monthlyBudgetMinor: 0,
      dailyBudgetMinor: 0,
      rules: [rule],
    );
    final p = parseBackup(json);
    expect(p.rules.length, 1);
    expect(p.rules.single.dupKey, rule.dupKey);
    expect(p.rules.single.lastGenerated, DateTime(2026, 3, 1));
    expect(p.rules.single.endDate, DateTime(2026, 12, 1));
  });

  test('old backups without rules still load', () {
    final p = parseBackup('{"app":"DayWise","schema":1,"transactions":[]}');
    expect(p.rules, isEmpty);
  });

  test('rejects foreign files', () {
    expect(() => parseBackup('not json'), throwsFormatException);
    expect(
      () => parseBackup('{"app":"Other","transactions":[]}'),
      throwsFormatException,
    );
    expect(
      () => parseBackup('{"app":"DayWise","schema":99,"transactions":[]}'),
      throwsFormatException,
    );
  });

  test('skips bad rows instead of failing', () {
    const json =
        '{"app":"DayWise","schema":1,"transactions":['
        '{"date":"2026-10-01","amountMinor":100,"type":"expense","categoryId":"food"},'
        '{"date":"2026-13-45","amountMinor":100,"type":"expense","categoryId":"food"},'
        '{"date":"2026-10-01","amountMinor":-5,"type":"expense","categoryId":"food"},'
        '{"oops":true}]}';
    final p = parseBackup(json);
    expect(p.txns.length, 1);
    expect(p.skipped, 3);
  });

  test('csv escaping', () {
    final csv = encodeCsv(
      txns,
      (id) => id == 'food' ? 'Food & Dining' : 'Salary',
    );
    final lines = csv.trim().split('\r\n');
    expect(lines.first, 'Date,Time,Account,Type,Category,Amount,Note');
    expect(
      lines[1],
      '2026-10-01,00:00,everyday,Expense,Food & Dining,120.50,"Lunch, with ""friends"""',
    );
    expect(lines[2], '2026-10-02,00:00,everyday,Income,Salary,50000.00,');
  });

  test('accounts and selected transaction times survive backup and CSV', () {
    const account = MoneyAccount(
      id: 'bank-2',
      name: 'Savings, joint',
      openingBalanceMinor: 123456,
    );
    final date = DateTime(2026, 11, 5, 18, 42);
    final entry = Txn(
      date: date,
      accountId: account.id,
      amountMinor: 4500,
      type: TxType.expense,
      categoryId: 'food',
      createdAt: 1,
    );
    final rule = RecurringRule(
      type: TxType.income,
      accountId: account.id,
      timeMinutes: 9 * 60 + 30,
      amountMinor: 50000,
      categoryId: 'salary',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 11, 1),
      createdAt: 1,
    );
    final restored = parseBackup(
      encodeBackup(
        txns: [entry],
        categories: [],
        accounts: [account],
        rules: [rule],
        currency: 'INR',
        monthlyBudgetMinor: 0,
        dailyBudgetMinor: 0,
      ),
    );
    expect(restored.txns.single.date, date);
    expect(restored.txns.single.accountId, account.id);
    expect(
      restored.accounts
          .firstWhere((a) => a.id == account.id)
          .openingBalanceMinor,
      123456,
    );
    expect(restored.rules.single.accountId, account.id);
    expect(restored.rules.single.timeMinutes, 570);
    expect(
      encodeCsv([entry], (_) => 'Food', accountName: (_) => account.name),
      contains('2026-11-05,18:42,"Savings, joint",Expense,Food,45.00,'),
    );
  });

  test(
    'legacy entries get Everyday and unknown account references are recovered',
    () {
      final legacy = parseBackup(
        '{"app":"DayWise","schema":1,"transactions":[{"date":"2026-10-01","amountMinor":100}]}',
      );
      expect(legacy.txns.single.accountId, kDefaultAccountId);
      expect(legacy.txns.single.date, DateTime(2026, 10, 1));
      expect(legacy.accounts.single.id, kDefaultAccountId);
      final recovered = parseBackup(
        '{"app":"DayWise","schema":2,"transactions":[{"date":"2026-10-01","amountMinor":100,"accountId":"missing"}]}',
      );
      expect(recovered.accounts.map((a) => a.id), contains('missing'));
    },
  );
}
