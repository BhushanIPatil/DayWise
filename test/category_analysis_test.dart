import 'package:daywise/core/format.dart';
import 'package:daywise/core/theme.dart';
import 'package:daywise/data/category_analysis.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/category_analysis.dart';
import 'package:daywise/ui/insights_page.dart';
import 'package:daywise/ui/record_view_options.dart';
import 'package:daywise/ui/report_export.dart';
import 'package:daywise/ui/transaction_list.dart';
import 'package:daywise/ui/week_page.dart';
import 'package:daywise/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const food = Category(
  id: 'food',
  name: 'Food',
  icon: 'restaurant',
  color: 0xFFEF6C00,
  type: TxType.expense,
);
const travel = Category(
  id: 'travel',
  name: 'Travel',
  icon: 'travel',
  color: 0xFF00897B,
  type: TxType.expense,
);
const salary = Category(
  id: 'salary',
  name: 'Salary',
  icon: 'salary',
  color: 0xFF388E3C,
  type: TxType.income,
);

class _Db extends AppDb {
  @override
  Future<List<MoneyAccount>> accounts() async => [
    kDefaultAccount,
    const MoneyAccount(id: 'bank', name: 'Bank'),
  ];
  @override
  Future<List<Category>> categories() async => [
    kDefaultCategory,
    food,
    travel,
    salary,
  ];
  @override
  Future<List<RecurringRule>> rules() async => [];
  @override
  Future<List<Txn>> allTxns() async => [
    record(1, 'food', 10000, TxType.expense, 'Breakfast'),
    record(2, 'food', 20000, TxType.expense, 'Dinner', bank: true),
    record(3, 'travel', 10000, TxType.expense, 'Train'),
    record(4, 'food', 5000, TxType.income, 'Refund'),
    record(5, 'salary', 15000, TxType.income, 'Wages', bank: true),
    record(
      6,
      'food',
      99999,
      TxType.expense,
      'Old',
      date: addDays(DateTime.now(), -60),
    ),
  ];
}

Txn record(
  int id,
  String category,
  Object amount,
  TxType type,
  String note, {
  bool bank = false,
  DateTime? date,
}) => Txn(
  id: id,
  date: date ?? DateTime.now(),
  amountMinor: amount,
  type: type,
  categoryId: category,
  note: note,
  accountId: bank ? 'bank' : kDefaultAccountId,
  createdAt: id,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(_Db(), await SharedPreferences.getInstance());
    await state.load();
  });
  tearDown(() => state.dispose());
  Widget app(Widget page) => AppScope(
    state: state,
    child: MaterialApp(
      theme: buildTheme(Brightness.light, Brand.accents.first),
      home: Scaffold(body: page),
    ),
  );

  test(
    'category grouping separates types and preserves arbitrary size amounts',
    () {
      final huge = BigInt.parse('999999999999999999999999999999999');
      final entries = [
        record(1, 'food', huge, TxType.expense, ''),
        record(2, 'food', 1, TxType.expense, ''),
        record(3, 'food', 999, TxType.income, ''),
        record(4, 'missing', 100, TxType.expense, ''),
        record(5, kDefaultCategoryId, 200, TxType.expense, ''),
      ];
      final rows = categoryTotals(entries, TxType.expense, state.categoryById);
      expect(rows.map((r) => r.category.id), ['food', kDefaultCategoryId]);
      expect(rows.first.amountMinor, huge + BigInt.one);
      expect(rows.first.count, 2);
      expect(rows.last.amountMinor, BigInt.from(300));
      expect(rows.last.count, 2);
      expect(
        categoryTotals(
          entries,
          TxType.income,
          state.categoryById,
        ).single.amountMinor,
        BigInt.from(999),
      );
    },
  );

  for (final insights in [false, true]) {
    testWidgets(
      'category totals, drilldown and stable header: insights=$insights',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(insights ? const InsightsPage() : const WeekPage()),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnalysisViewToggle>(find.byType(AnalysisViewToggle))
              .value,
          AnalysisView.overview,
        );
        final menu = tester.getCenter(find.byTooltip('More options'));
        final period = tester.getCenter(find.byType(PeriodNavigator));
        final toggle = tester.getTopLeft(find.byType(AnalysisViewToggle));
        expect(toggle.dy, greaterThan(period.dy));
        expect(toggle.dy, greaterThan(menu.dy));
        final search = insights
            ? tester.getCenter(find.byTooltip('Search'))
            : null;
        await tester.tap(find.text('Categories'));
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byTooltip('More options')), menu);
        expect(tester.getCenter(find.byType(PeriodNavigator)), period);
        if (search != null) {
          expect(tester.getCenter(find.byTooltip('Search')), search);
        }
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('category-total-expense')),
              )
              .data,
          state.money.full(40000),
        );
        final row = find.byKey(const ValueKey('category-row-expense-food'));
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.descendant(
                  of: row,
                  matching: find.byType(LinearProgressIndicator),
                ),
              )
              .value,
          0.75,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.textContaining('2 transactions'),
          ),
          findsOneWidget,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TransactionList>(find.byType(TransactionList))
              .entries
              .map((t) => t.note),
          ['Dinner', 'Breakfast'],
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        state.selectAccount('bank');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('category-total-expense')),
              )
              .data,
          state.money.full(20000),
        );
        final data = tester.widget<CategoryAnalysis>(
          find.byType(CategoryAnalysis),
        );
        expect(
          data.entries.map((t) => t.note),
          containsAll(['Dinner', 'Wages']),
        );
        expect(data.entries, hasLength(2));
        if (insights) {
          await tester.tap(find.byTooltip('Record type'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (w) =>
                  w is CheckedPopupMenuItem<RecordSortChoice> &&
                  w.value == RecordSortChoice.income,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Expense by category'), findsNothing);
          expect(find.text('Income by category'), findsOneWidget);
          await tester.tap(find.byTooltip('Search'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('record-search')),
            'salary',
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ReportExport>(find.byType(ReportExport))
                .entries!
                .single
                .note,
            'Wages',
          );
          await tester.enterText(
            find.byKey(const ValueKey('record-search')),
            'not found',
          );
          await tester.pumpAndSettle();
          expect(find.text('No category data'), findsOneWidget);
          expect(
            tester.widget<ReportExport>(find.byType(ReportExport)).entries,
            isEmpty,
          );
          await tester.tap(find.byTooltip('Close search'));
          await tester.pumpAndSettle();
        }
        final navigator = tester.widget<PeriodNavigator>(
          find.byType(PeriodNavigator),
        );
        navigator.onNext();
        await tester.pumpAndSettle();
        expect(find.text('No category data'), findsOneWidget);
        await tester.tap(find.text('Overview'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryAnalysis), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
