import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/accounts_page.dart';
import 'package:daywise/ui/date_time_fields.dart';
import 'package:daywise/ui/entry_sheet.dart';
import 'package:daywise/ui/recurring_page.dart';
import 'package:daywise/ui/transaction_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDb extends AppDb {
  final savedAccounts = [
    kDefaultAccount,
    const MoneyAccount(id: 'bank', name: 'Savings'),
  ];
  final entries = [
    Txn(
      id: 1,
      date: DateTime.now(),
      amountMinor: 2500,
      type: TxType.expense,
      accountId: 'bank',
      createdAt: 1,
    ),
  ];
  final savedRules = [
    RecurringRule(
      id: 1,
      type: TxType.expense,
      amountMinor: 1000,
      accountId: 'bank',
      frequency: Frequency.monthly,
      startDate: DateTime(2090),
      createdAt: 1,
    ),
  ];
  int deleteCalls = 0;
  bool failDelete = false;

  @override
  Future<List<MoneyAccount>> accounts() async => [...savedAccounts];
  @override
  Future<List<Category>> categories() async => [];
  @override
  Future<List<Txn>> allTxns() async => [...entries];
  @override
  Future<List<RecurringRule>> rules() async => [...savedRules];
  @override
  Future<void> upsertAccount(MoneyAccount account) async {
    final index = savedAccounts.indexWhere((a) => a.id == account.id);
    if (index < 0) {
      savedAccounts.add(account);
    } else {
      savedAccounts[index] = account;
    }
  }

  @override
  Future<void> createAccount(MoneyAccount account, DateTime openingDate) async {
    savedAccounts.add(
      MoneyAccount(id: account.id, name: account.name, color: account.color),
    );
    if (account.openingBalanceMinor != BigInt.zero) {
      entries.add(
        Txn(
          id: entries.length + 1,
          date: openingDate,
          accountId: account.id,
          amountMinor: account.openingBalanceMinor.abs(),
          type: account.openingBalanceMinor > BigInt.zero
              ? TxType.income
              : TxType.expense,
          note: 'Opening balance',
          createdAt: 1,
        ),
      );
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    deleteCalls++;
    if (failDelete) throw StateError('Database unavailable');
    savedAccounts.removeWhere((a) => a.id == id);
    entries.removeWhere((t) => t.accountId == id);
    savedRules.removeWhere((r) => r.accountId == id);
  }
}

void main() {
  late _MemoryDb db;
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = _MemoryDb();
    state = AppState(db, await SharedPreferences.getInstance());
    await state.load();
  });
  tearDown(() => state.dispose());
  Widget app(Widget page) => AppScope(
    state: state,
    child: MaterialApp(
      theme: buildTheme(Brightness.light, Brand.accents.first),
      home: page,
    ),
  );
  Future<void> deleteMenu(WidgetTester tester, String name) async {
    final button = find.byTooltip('Options for $name');
    await Scrollable.ensureVisible(tester.element(button), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'account creation offers a timestamp and records its opening income once',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAccountEditor(context),
                child: const Text('Create'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryDateTimeFields), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Account name'),
        'Cash',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Opening balance'),
        '5000',
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Saved as an income record.'), findsOneWidget);
      final date = DateTime(2026, 11, 9, 18, 45);
      tester
          .widget<EntryDateTimeFields>(find.byType(EntryDateTimeFields))
          .onChanged(date);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.widgetWithText(FilledButton, 'Save account'))
            .bottom,
        lessThanOrEqualTo(740 - 260),
      );
      await tester.tap(find.text('Save account'));
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      final account = state.accounts.firstWhere((a) => a.name == 'Cash');
      final opening = state.transactionsForAccount(account.id).single;
      expect(opening.type, TxType.income);
      expect(opening.amountMinor, BigInt.from(500000));
      expect(opening.date, date);
      expect(account.openingBalanceMinor, BigInt.from(0));
      expect(state.accountBalance(account.id), BigInt.from(500000));
      final editAccount = state.accountById(account.id);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showAccountEditor(context, account: editAccount),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Opening balance'), findsNothing);
      await tester.ensureVisible(find.text('Save account'));
      await tester.tap(find.text('Save account'));
      await tester.pumpAndSettle();
      expect(state.transactionsForAccount(account.id), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting an account requires confirmation and cancel preserves its data',
    (tester) async {
      state.selectAccount('bank');
      await tester.pumpWidget(app(const AccountsPage()));
      await deleteMenu(tester, 'Savings');
      expect(find.text('Delete Savings?'), findsOneWidget);
      expect(
        find.textContaining('1 income and expense record'),
        findsOneWidget,
      );
      expect(find.textContaining('1 recurring rule'), findsOneWidget);
      expect(db.deleteCalls, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(state.accounts.length, 2);
      expect(state.all.length, 1);
      expect(state.rules.length, 1);
      await deleteMenu(tester, 'Savings');
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(db.deleteCalls, 1);
      expect(state.accounts.single.id, kDefaultAccountId);
      expect(state.selectedAccountId, isNull);
      expect(state.all, isEmpty);
      expect(state.rules, isEmpty);
      expect(find.byTooltip('Options for Savings'), findsNothing);
      await deleteMenu(tester, 'Everyday');
      expect(find.text('Keep at least one account'), findsOneWidget);
      expect(find.text('Delete account'), findsNothing);
      expect(db.deleteCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account editing remains available and deletion errors keep the account',
    (tester) async {
      await tester.pumpWidget(app(const AccountsPage()));
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Options for Savings')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Options for Savings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Account name'),
        'Rainy day',
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save account'));
      await tester.tap(find.text('Save account'));
      await tester.pumpAndSettle();
      expect(state.accountById('bank').name, 'Rainy day');
      db.failDelete = true;
      await deleteMenu(tester, 'Rainy day');
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(state.accounts.length, 2);
      expect(state.all.length, 1);
      expect(
        find.text('Could not delete this account. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new records and rules use a remaining account after Everyday is deleted',
    (tester) async {
      await state.deleteAccount(kDefaultAccountId);
      for (final recurring in [false, true]) {
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    if (recurring) {
                      showRuleEditor(context);
                    } else {
                      showEntrySheet(context);
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AccountField>(find.byType(AccountField)).value,
          'bank',
        );
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(AccountField))).pop();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'account activity shares ledger rows and shows coloured income, expense and balance totals',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const AccountsPage()));
      final button = find.widgetWithText(TextButton, 'View activity').last;
      await Scrollable.ensureVisible(tester.element(button), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionRecordRow), findsOneWidget);
      final income = tester.widget<Text>(
        find.byKey(const ValueKey('account-activity-income')),
      );
      final expense = tester.widget<Text>(
        find.byKey(const ValueKey('account-activity-expenses')),
      );
      final balance = tester.widget<Text>(
        find.byKey(const ValueKey('account-activity-balance')),
      );
      expect(income.data, state.money.full(0));
      expect(income.style!.color, Brand.income);
      expect(expense.data, state.money.full(2500));
      expect(expense.style!.color, Brand.expense);
      expect(balance.data, state.money.full(-2500));
      expect(balance.style!.color, Brand.expense);
      expect(find.text('Balance after'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
