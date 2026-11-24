import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/accounts_page.dart';
import 'package:daywise/ui/budget_editor.dart';
import 'package:daywise/ui/budgets_page.dart';
import 'package:daywise/ui/date_time_fields.dart';
import 'package:daywise/ui/recurring_page.dart';
import 'package:daywise/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDb extends AppDb {
  final savedRules = [
    RecurringRule(
      id: 1,
      type: TxType.expense,
      amountMinor: 10000,
      accountId: 'bank',
      timeMinutes: 15 * 60 + 45,
      note: 'Rent',
      frequency: Frequency.monthly,
      startDate: DateTime(2090, 1, 1),
      endDate: DateTime(2090, 12, 31),
      createdAt: 1,
    ),
  ];
  final entries = [
    Txn(
      id: 1,
      date: DateTime.now(),
      amountMinor: 10000,
      type: TxType.expense,
      note: 'Recorded rent',
      createdAt: 1,
    ),
  ];
  @override
  Future<List<MoneyAccount>> accounts() async => [
    kDefaultAccount,
    const MoneyAccount(id: 'bank', name: 'Savings'),
  ];
  @override
  Future<List<Category>> categories() async => [];
  @override
  Future<List<Txn>> allTxns() async => [...entries];
  @override
  Future<List<RecurringRule>> rules() async => [...savedRules];
  @override
  Future<int> upsertRule(RecurringRule rule) async {
    final id = rule.id ?? 2;
    savedRules.removeWhere((item) => item.id == id);
    savedRules.add(rule.copyWith(id: id));
    return id;
  }

  @override
  Future<void> deleteRule(int id) async =>
      savedRules.removeWhere((rule) => rule.id == id);
}

void main() {
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(_MemoryDb(), await SharedPreferences.getInstance());
    await state.load();
  });
  tearDown(() => state.dispose());
  Widget app(Widget child) => AppScope(
    state: state,
    child: MaterialApp(
      theme: buildTheme(Brightness.light, Brand.accents.first),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );

  for (final monthly in [true, false]) {
    testWidgets(
      'separate budget page lists accounts and provides edit and delete: monthly=$monthly',
      (tester) async {
        if (monthly) {
          state.setMonthlyBudget(10000, accountId: kDefaultAccountId);
          state.setMonthlyBudget(20000, accountId: 'bank');
        } else {
          state.setDailyBudget(10000, accountId: kDefaultAccountId);
          state.setDailyBudget(20000, accountId: 'bank');
        }
        await tester.pumpWidget(app(BudgetsPage(monthly: monthly)));
        await tester.pumpAndSettle();
        expect(
          find.text(monthly ? 'Monthly budgets' : 'Daily budgets'),
          findsOneWidget,
        );
        expect(find.byType(AccountBadge), findsNWidgets(2));
        final menu = find.byTooltip('Budget options for Savings');
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit budget'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AccountField>(find.byType(AccountField)).value,
          'bank',
        );
        final field = find.byKey(const ValueKey('budget-amount'));
        expect(tester.widget<TextField>(field).controller!.text, '200');
        await tester.enterText(field, '250');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          monthly
              ? state.budgetForAccount('bank').monthlyMinor
              : state.budgetForAccount('bank').dailyMinor,
          25000,
        );
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete budget'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.byType(AccountBadge), findsOneWidget);
        expect(state.all, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'account budget editor saves, edits and confirms deletion: monthly=$monthly',
      (tester) async {
        state.setMonthlyBudget(1000, accountId: kDefaultAccountId);
        state.setDailyBudget(100, accountId: kDefaultAccountId);
        state.selectAccount('bank');
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showBudgetEditor(context, monthly: monthly),
                child: const Text('Open budget'),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('Open budget'));
          await tester.pumpAndSettle();
        }

        await open();
        expect(
          tester.widget<AccountField>(find.byType(AccountField)).value,
          'bank',
        );
        final field = find.byKey(const ValueKey('budget-amount'));
        await tester.enterText(field, '500');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        int value() => monthly
            ? state.budgetForAccount('bank').monthlyMinor
            : state.budgetForAccount('bank').dailyMinor;
        expect(value(), 50000);
        expect(state.budgetForAccount(kDefaultAccountId).monthlyMinor, 1000);
        expect(state.budgetForAccount(kDefaultAccountId).dailyMinor, 100);
        await open();
        expect(tester.widget<TextField>(field).controller!.text, '500');
        await tester.enterText(field, '650');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(value(), 65000);
        await open();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(value(), 65000);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(value(), 0);
        expect(state.all.single.note, 'Recorded rent');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'account badge text has strong contrast in light and dark themes',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final color in Brand.accents) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(brightness, Brand.accents.first),
              home: Scaffold(
                body: AccountBadge(
                  account: MoneyAccount(
                    id: 'test',
                    name: 'Savings',
                    color: color.toARGB32(),
                  ),
                ),
              ),
            ),
          );
          final text = tester.widget<Text>(find.text('Savings'));
          final container = tester.widget<Container>(
            find.descendant(
              of: find.byType(AccountBadge),
              matching: find.byType(Container),
            ),
          );
          final background = (container.decoration! as BoxDecoration).color!
              .computeLuminance();
          final foreground = text.style!.color!.computeLuminance();
          final contrast = foreground > background
              ? (foreground + .05) / (background + .05)
              : (background + .05) / (foreground + .05);
          expect(contrast, greaterThanOrEqualTo(4.5));
        }
      }
    },
  );

  testWidgets(
    'recurring account badge and AM/PM survive editing and confirmed deletion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const RecurringPage()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AccountBadge>(find.byType(AccountBadge)).account.name,
        'Savings',
      );
      expect(find.text('3:45 PM'), findsOneWidget);
      Future<void> menu(String action) async {
        await tester.tap(find.byTooltip('Recurring entry options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      await menu('Edit rule');
      expect(find.text('Edit recurring entry'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '125');
      await tester.enterText(find.byType(TextField).last, 'Updated rent');
      tester
          .widget<EntryDateTimeFields>(find.byType(EntryDateTimeFields))
          .onChanged(DateTime(2090, 1, 1, 18, 30));
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Remove end date'));
      await tester.tap(find.byTooltip('Remove end date'));
      await tester.pumpAndSettle();
      expect(find.text('No end date'), findsOneWidget);
      await tester.tap(find.text('Save rule'));
      await tester.pumpAndSettle();
      expect(state.rules.single.id, 1);
      expect(state.rules.single.amountMinor, BigInt.from(12500));
      expect(state.rules.single.endDate, isNull);
      expect(find.text('6:30 PM'), findsOneWidget);
      expect(state.all.single.note, 'Recorded rent');
      await menu('Delete rule');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(state.rules, hasLength(1));
      await menu('Delete rule');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete rule'));
      await tester.pumpAndSettle();
      expect(state.rules, isEmpty);
      expect(state.all.single.note, 'Recorded rent');
      expect(tester.takeException(), isNull);
    },
  );
}
