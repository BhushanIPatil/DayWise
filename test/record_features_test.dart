import 'fixtures/legacy_categories.dart';
import 'dart:async';
import 'dart:convert';

import 'package:daywise/core/format.dart';
import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/backup.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/data/report.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/accounts_page.dart';
import 'package:daywise/ui/calendar_page.dart';
import 'package:daywise/ui/chart_value_bar.dart';
import 'package:daywise/ui/day_page.dart';
import 'package:daywise/ui/budgets_page.dart';
import 'package:daywise/ui/date_budget_indicators.dart';
import 'package:daywise/ui/date_time_fields.dart';
import 'package:daywise/ui/home_shell.dart';
import 'package:daywise/ui/insights_page.dart';
import 'package:daywise/ui/report_period.dart';
import 'package:daywise/ui/week_page.dart';
import 'package:daywise/ui/records_page.dart';
import 'package:daywise/ui/record_view_options.dart';
import 'package:daywise/ui/transaction_list.dart';
import 'package:daywise/ui/recurring_page.dart';
import 'package:daywise/ui/report_export.dart';
import 'package:daywise/ui/settings_page.dart';
import 'package:daywise/ui/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDb extends AppDb {
  @override
  Future<int> upsertTxn(Txn t) async => 99;
  @override
  Future<List<MoneyAccount>> accounts() async => [
    kDefaultAccount,
    const MoneyAccount(id: 'bank', name: 'Savings'),
  ];
  @override
  Future<List<Category>> categories() async => kDefaultCategories;
  @override
  Future<List<RecurringRule>> rules() async => [];
  @override
  Future<List<Txn>> allTxns() async => [
    Txn(
      date: DateTime(DateTime.now().year, DateTime.now().month, 10, 9),
      amountMinor: 5000,
      type: TxType.expense,
      categoryId: 'food',
      note: 'Breakfast',
      createdAt: 1,
    ),
    Txn(
      date: DateTime(DateTime.now().year, DateTime.now().month, 10, 15),
      amountMinor: 15000,
      type: TxType.expense,
      categoryId: 'food',
      note: 'Lunch',
      accountId: 'bank',
      createdAt: 2,
    ),
    Txn(
      date: DateTime(DateTime.now().year, DateTime.now().month, 9, 9),
      amountMinor: 2000,
      type: TxType.expense,
      categoryId: 'food',
      note: 'Coffee',
      createdAt: 3,
    ),
  ];
}

class _PendingPicker extends FilePickerPlatform {
  final picked = Completer<PlatformFile?>();
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) => picked.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
      home: Scaffold(body: child),
    ),
  );

  testWidgets('day page filters accounts, type and search and scopes exports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = DateTime(DateTime.now().year, DateTime.now().month, 10);
    await state.addTxn(
      Txn(
        date: day,
        amountMinor: 10000,
        type: TxType.income,
        accountId: 'bank',
        note: 'Salary',
        createdAt: 4,
      ),
    );
    await tester.pumpWidget(app(DayPage(initial: day)));
    await tester.pumpAndSettle();
    List<Txn> visible() =>
        tester.widget<TransactionList>(find.byType(TransactionList)).entries;
    expect(visible(), hasLength(3));
    expect(find.byType(SliverPersistentHeader), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('day-heading'))).data,
      equals('${fmtWeekday(day)}, ${fmtDayLong(day)}'),
    );
    expect(
      tester.getCenter(find.byType(BackButton)).dy,
      tester.getCenter(find.byTooltip('Search')).dy,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('day-heading'))).dy,
      tester.getCenter(find.byTooltip('Record type')).dy,
    );
    await tester.tap(find.byTooltip('Record type'));
    await tester.pumpAndSettle();
    expect(find.text('Date ascending'), findsNothing);
    expect(find.text('Date descending'), findsNothing);
    expect(
      find.byType(CheckedPopupMenuItem<RecordSortChoice>),
      findsNWidgets(3),
    );
    final both = find.byWidgetPredicate(
      (w) =>
          w is CheckedPopupMenuItem<RecordSortChoice> &&
          w.value == RecordSortChoice.both,
    );
    expect(
      tester.widget<CheckedPopupMenuItem<RecordSortChoice>>(both).checked,
      isTrue,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is CheckedPopupMenuItem<RecordSortChoice> &&
            w.value == RecordSortChoice.expense,
      ),
    );
    await tester.pumpAndSettle();
    expect(visible(), hasLength(2));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Savings').last);
    await tester.pumpAndSettle();
    expect(visible().single.note, 'Lunch');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('record-search')),
      'Salary',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing recorded'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(visible().single.note, 'Lunch');
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
    expect(visible().single.note, 'Salary');
    await tester.tap(find.byTooltip('Record type'));
    await tester.pumpAndSettle();
    await tester.tap(both);
    await tester.pumpAndSettle();
    final export = tester.widget<ReportExport>(find.byType(ReportExport));
    expect(
      export.entries!.map((t) => t.note),
      containsAll(['Lunch', 'Salary']),
    );
    expect(export.entries, hasLength(2));
    expect(export.from, day);
    expect(export.to, day);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    for (final label in ['Save PDF', 'Share PDF', 'Save CSV', 'Share CSV']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Manage accounts'), findsNothing);
    await tester.tapAt(const Offset(5, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing recorded'), findsOneWidget);
    expect(
      tester.widget<ReportExport>(find.byType(ReportExport)).from,
      addDays(day, 1),
    );
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(visible(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  test('export range includes the end day and respects account selection', () {
    final date = DateTime(DateTime.now().year, DateTime.now().month, 10);
    expect(state.recordsInRange(date, date).length, 2);
    state.selectAccount('bank');
    expect(state.recordsInRange(date, date).single.note, 'Lunch');
    expect(
      state.recordsInRange(
        null,
        DateTime(DateTime.now().year, DateTime.now().month, 9),
      ),
      isEmpty,
    );
  });

  Future<void> chooseSort(WidgetTester tester, RecordSortChoice choice) async {
    final sort = find.byTooltip('Sort and record type');
    await tester.tap(
      sort.evaluate().isNotEmpty ? sort : find.byTooltip('Record type'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<RecordSortChoice> &&
            widget.value == choice,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final weekly in [false, true]) {
    testWidgets(
      'calendar type filters default to both and scope content: weekly=$weekly',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now();
        await state.addTxn(
          Txn(
            date: now,
            amountMinor: 77000,
            type: TxType.income,
            note: 'Current income',
            createdAt: 10,
          ),
        );
        await state.addTxn(
          Txn(
            date: now,
            amountMinor: 33000,
            type: TxType.expense,
            note: 'Current expense',
            createdAt: 11,
          ),
        );
        await tester.pumpWidget(
          app(weekly ? const WeekPage() : const CalendarPage()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Record type'));
        await tester.pumpAndSettle();
        final items = tester.widgetList<CheckedPopupMenuItem<RecordSortChoice>>(
          find.byType(CheckedPopupMenuItem<RecordSortChoice>),
        );
        expect(items, hasLength(3));
        expect(
          items.singleWhere((item) => item.checked).value,
          RecordSortChoice.both,
        );
        expect(find.text('Date ascending'), findsNothing);
        expect(find.text('Date descending'), findsNothing);
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is CheckedPopupMenuItem<RecordSortChoice> &&
                w.value == RecordSortChoice.income,
          ),
        );
        await tester.pumpAndSettle();
        List<Txn> exported() =>
            tester.widget<ReportExport>(find.byType(ReportExport)).entries!;
        expect(exported(), isNotEmpty);
        expect(exported().every((t) => t.isIncome), isTrue);
        if (weekly) {
          expect(find.text('Income this week'), findsOneWidget);
          expect(
            tester
                .widgetList<ChartValueBar>(find.byType(ChartValueBar))
                .where((bar) => bar.value > BigInt.zero)
                .every((bar) => bar.color == Brand.income),
            isTrue,
          );
          await tester.tap(find.text('Categories'));
          await tester.pumpAndSettle();
          expect(find.text('Expense by category'), findsNothing);
          expect(find.text('Income by category'), findsOneWidget);
        } else {
          expect(find.text('Expense'), findsNothing);
          await tester.tap(find.text(now.day.toString()).first);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TransactionList>(find.byType(TransactionList))
                .entries
                .every((t) => t.isIncome),
            isTrue,
          );
          expect(find.byType(SliverPersistentHeader), findsNothing);
          expect(find.byKey(const ValueKey('day-heading')), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await chooseSort(tester, RecordSortChoice.expense);
        expect(exported(), isNotEmpty);
        expect(exported().every((t) => !t.isIncome), isTrue);
        await chooseSort(tester, RecordSortChoice.both);
        expect(exported().any((t) => t.isIncome), isTrue);
        expect(exported().any((t) => !t.isIncome), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'search is before overflow and the period row has week or sort controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in [
        CalendarPage(onWeekView: () {}),
        const RecordsPage(),
        const InsightsPage(),
      ]) {
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        final search = tester.getCenter(find.byTooltip('Search'));
        final menu = tester.getCenter(find.byTooltip('More options'));
        expect(search.dx, lessThan(menu.dx));
        expect(search.dy, menu.dy);
        final secondary = tester.getCenter(
          find.byTooltip(
            page is CalendarPage
                ? 'Switch to week'
                : page is InsightsPage
                ? 'Record type'
                : 'Sort and record type',
          ),
        );
        expect(secondary.dy, greaterThan(search.dy));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'list sorts dates independently of income and expense filtering and search',
    (tester) async {
      await state.addTxn(
        Txn(
          date: DateTime(DateTime.now().year, DateTime.now().month, 8, 10),
          amountMinor: 30000,
          type: TxType.income,
          note: 'Salary',
          createdAt: 4,
        ),
      );
      await tester.pumpWidget(app(const RecordsPage()));
      await tester.pumpAndSettle();
      List<Txn> visible() =>
          tester.widget<TransactionList>(find.byType(TransactionList)).entries;
      expect(visible().first.note, 'Lunch');
      expect(visible().last.note, 'Salary');
      await tester.tap(find.byTooltip('Sort and record type'));
      await tester.pumpAndSettle();
      final choices = tester.widgetList<CheckedPopupMenuItem<RecordSortChoice>>(
        find.byType(CheckedPopupMenuItem<RecordSortChoice>),
      );
      expect(
        choices.where((choice) => choice.checked).map((choice) => choice.value),
        containsAll([RecordSortChoice.descending, RecordSortChoice.both]),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<RecordSortChoice> &&
              widget.value == RecordSortChoice.ascending,
        ),
      );
      await tester.pumpAndSettle();
      expect(visible().first.note, 'Salary');
      expect(visible().last.note, 'Lunch');
      await chooseSort(tester, RecordSortChoice.income);
      expect(visible().single.note, 'Salary');
      expect(
        tester
            .widget<ReportExport>(find.byType(ReportExport))
            .entries!
            .single
            .isIncome,
        isTrue,
      );
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-search')),
        'Lunch',
      );
      await tester.pumpAndSettle();
      expect(visible(), isEmpty);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      await chooseSort(tester, RecordSortChoice.expense);
      expect(visible().every((txn) => !txn.isIncome), isTrue);
      expect(visible().first.note, 'Coffee');
      await chooseSort(tester, RecordSortChoice.both);
      expect(visible(), hasLength(4));
      expect(visible().first.note, 'Salary');
      await chooseSort(tester, RecordSortChoice.descending);
      expect(visible().first.note, 'Lunch');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('insights filters its totals, chart, search and export records', (
    tester,
  ) async {
    await state.addTxn(
      Txn(
        date: DateTime(DateTime.now().year, DateTime.now().month, 8, 10),
        amountMinor: 30000,
        type: TxType.income,
        note: 'Salary',
        createdAt: 4,
      ),
    );
    await tester.pumpWidget(app(const InsightsPage()));
    await tester.pumpAndSettle();
    final expenseBar = find.byWidgetPredicate(
      (widget) => widget is ChartValueBar && widget.value == BigInt.from(20000),
    );
    expect(expenseBar, findsOneWidget);
    expect(
      find.descendant(
        of: expenseBar,
        matching: find.text(state.money.compact(20000)),
      ),
      findsOneWidget,
    );
    final first = DateTime(DateTime.now().year, DateTime.now().month);
    final last = DateTime(first.year, first.month + 1, 0);
    final firstBar = find.byKey(ValueKey('insight-day-${dateKey(first)}'));
    final lastBar = find.byKey(ValueKey('insight-day-${dateKey(last)}'));
    expect(
      tester.getTopLeft(firstBar).dx,
      lessThan(tester.getTopLeft(lastBar).dx),
    );
    await tester.tap(find.byTooltip('Record type'));
    await tester.pumpAndSettle();
    expect(find.text('Date ascending'), findsNothing);
    expect(find.text('Date descending'), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is CheckedPopupMenuItem<RecordSortChoice> &&
            w.value == RecordSortChoice.both,
      ),
    );
    await tester.pumpAndSettle();
    await chooseSort(tester, RecordSortChoice.income);
    expect(find.text('Spent'), findsNothing);
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Income by day'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ChartValueBar && widget.value == BigInt.from(30000),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ReportExport>(find.byType(ReportExport))
          .entries!
          .single
          .note,
      'Salary',
    );
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('record-search')),
      'Lunch',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    await chooseSort(tester, RecordSortChoice.expense);
    expect(find.text('Income'), findsNothing);
    expect(
      tester
          .widget<ReportExport>(find.byType(ReportExport))
          .entries!
          .every((txn) => !txn.isIncome),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('categories appear in records and settings', (tester) async {
    await state.addTxn(
      Txn(
        date: DateTime.now(),
        amountMinor: 1000,
        type: TxType.expense,
        categoryId: 'food',
        createdAt: 5,
      ),
    );
    expect(state.search('Food & Dining'), isEmpty);
    expect(state.search('Breakfast'), hasLength(1));
    for (final page in [
      const RecordsPage(),
      const InsightsPage(),
      const WeekPage(),
      const SettingsPage(),
      const RecurringPage(),
    ]) {
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      expect(
        find.text('Categories'),
        page is SettingsPage || page is WeekPage || page is InsightsPage
            ? findsOneWidget
            : findsNothing,
      );
      if (page is RecordsPage) {
        expect(find.text('Food & Dining'), findsNothing);
        expect(find.byIcon(Icons.restaurant_rounded), findsWidgets);
      }
      expect(find.text('Where it went'), findsNothing);
      expect(find.text('Top categories'), findsNothing);
      if (page is RecordsPage) expect(find.byType(AccountBadge), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'week charts show labelled income and expense only when present',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final start = startOfWeek(DateTime.now(), state.weekStart);
      // Keep these dates separate from the existing fixture entries.
      final days = [
        for (var i = 0; i < 7; i++) addDays(start, i),
      ].where((day) => day.day != 9 && day.day != 10).take(4).toList();
      for (final record in [
        (days[0], TxType.income, 80000),
        (days[0], TxType.expense, 20000),
        (days[1], TxType.income, 40000),
        (days[2], TxType.expense, 10000),
      ]) {
        await state.addTxn(
          Txn(
            date: record.$1,
            type: record.$2,
            amountMinor: record.$3,
            createdAt: 1,
          ),
        );
      }
      await tester.pumpWidget(app(const WeekPage()));
      await tester.pumpAndSettle();

      List<ChartValueBar> bars(DateTime date) => tester
          .widgetList<ChartValueBar>(
            find.descendant(
              of: find.byKey(ValueKey('week-day-${dateKey(date)}')),
              matching: find.byType(ChartValueBar),
            ),
          )
          .toList();

      expect(
        bars(days[0]).map((bar) => bar.value),
        [80000, 20000].map(BigInt.from).toList(),
      );
      expect(bars(days[0]).map((bar) => bar.color), [
        Brand.income,
        Brand.expense,
      ]);
      expect(
        bars(days[0]).map((bar) => bar.maximum),
        [80000, 80000].map(BigInt.from).toList(),
      );
      expect(bars(days[1]).single.value, BigInt.from(40000));
      expect(bars(days[1]).single.color, Brand.income);
      expect(bars(days[2]).single.value, BigInt.from(10000));
      expect(bars(days[2]).single.color, Brand.expense);
      expect(bars(days[3]).single.value, BigInt.from(0));
      for (final value in [80000, 20000, 40000, 10000]) {
        expect(
          find.descendant(
            of: find.byType(ChartValueBar),
            matching: find.text(state.money.compact(value)),
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);

      state.selectAccount('bank');
      await tester.pumpAndSettle();
      for (final day in days) {
        expect(bars(day).single.value, BigInt.from(0));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('insights shows both series together and keeps type filters', (
    tester,
  ) async {
    final day = DateTime(DateTime.now().year, DateTime.now().month, 2);
    for (final record in [(TxType.income, 60000), (TxType.expense, 20000)]) {
      await state.addTxn(
        Txn(date: day, amountMinor: record.$2, type: record.$1, createdAt: 1),
      );
    }
    await tester.pumpWidget(app(const InsightsPage()));
    await tester.pumpAndSettle();
    List<ChartValueBar> dayBars() => tester
        .widgetList<ChartValueBar>(
          find.descendant(
            of: find.byKey(ValueKey('insight-day-${dateKey(day)}')),
            matching: find.byType(ChartValueBar),
          ),
        )
        .toList();
    expect(dayBars().map((bar) => bar.value), [
      BigInt.from(60000),
      BigInt.from(20000),
    ]);
    expect(dayBars().map((bar) => bar.color), [Brand.income, Brand.expense]);
    expect(dayBars().every((bar) => bar.maximum == BigInt.from(60000)), isTrue);
    void expectStat(TxType type, String metric, String value) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('insight-stat-${type.name}-$metric')),
          matching: find.text(value),
        ),
        findsOneWidget,
      );
    }

    void expectBothStatistics() {
      final elapsed = DateTime.now().day;
      expectStat(TxType.income, 'highest', state.money.full(60000));
      expectStat(TxType.expense, 'highest', state.money.full(20000));
      expectStat(
        TxType.income,
        'average',
        state.money.full(BigInt.from(60000) ~/ BigInt.from(elapsed)),
      );
      expectStat(
        TxType.expense,
        'average',
        state.money.full(BigInt.from(42000) ~/ BigInt.from(elapsed)),
      );
      expectStat(TxType.income, 'count', '1');
      expectStat(TxType.expense, 'count', '4');
      expectStat(
        TxType.income,
        'inactive',
        '${elapsed - (elapsed >= 2 ? 1 : 0)}',
      );
      expectStat(
        TxType.expense,
        'inactive',
        '${elapsed - [2, 9, 10].where((day) => day <= elapsed).length}',
      );
    }

    expectBothStatistics();
    await chooseSort(tester, RecordSortChoice.income);
    expect(dayBars().single.value, BigInt.from(60000));
    expectStat(TxType.income, 'highest', state.money.full(60000));
    expectStat(TxType.income, 'count', '1');
    expect(
      find.byKey(const ValueKey('insight-stat-expense-highest')),
      findsNothing,
    );
    expect(find.text('No-spend days'), findsNothing);
    await chooseSort(tester, RecordSortChoice.expense);
    expect(dayBars().single.value, BigInt.from(20000));
    expectStat(TxType.expense, 'highest', state.money.full(20000));
    expectStat(TxType.expense, 'count', '4');
    expect(
      find.byKey(const ValueKey('insight-stat-income-highest')),
      findsNothing,
    );
    expect(find.text('No-income days'), findsNothing);
    await chooseSort(tester, RecordSortChoice.both);
    expectBothStatistics();
    expect(dayBars().map((bar) => bar.color), [Brand.income, Brand.expense]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar puts income above expense in each date cell', (
    tester,
  ) async {
    final day = DateTime(DateTime.now().year, DateTime.now().month, 10);
    await state.addTxn(
      Txn(date: day, amountMinor: 30000, type: TxType.income, createdAt: 1),
    );
    await tester.pumpWidget(app(const CalendarPage()));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('+300')).dy,
      lessThan(tester.getTopLeft(find.text('200')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('records share date labels and retain notes and account filter', (
    tester,
  ) async {
    await tester.pumpWidget(app(const RecordsPage()));
    expect(
      find.text(
        fmtDayLong(DateTime(DateTime.now().year, DateTime.now().month, 10)),
      ),
      findsOneWidget,
    );
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.byType(ReportExport), findsOneWidget);
    state.selectAccount('bank');
    await tester.pump();
    expect(find.text('Breakfast'), findsNothing);
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets(
    'date headings stay pinned until the next transaction group replaces them',
    (tester) async {
      tester.view.physicalSize = const Size(320, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final current = DateTime(DateTime.now().year, DateTime.now().month, 20);
      final previous = addDays(current, -1);
      for (final day in [current, previous]) {
        for (var i = 0; i < 8; i++) {
          await state.addTxn(
            Txn(
              date: DateTime(day.year, day.month, day.day, 12, i),
              amountMinor: 1000,
              type: TxType.expense,
              note: 'Purchase details',
              createdAt: i,
            ),
          );
        }
      }
      await tester.pumpWidget(
        app(
          TransactionList(
            entries: state.recordsInRange(previous, current),
            header: const SizedBox(height: 120),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byType(CustomScrollView);
      final first = find.byKey(
        ValueKey('transaction-date-band-${dateKey(current)}'),
      );
      final second = find.byKey(
        ValueKey('transaction-date-band-${dateKey(previous)}'),
      );
      final top = tester.getTopLeft(scroll).dy;
      await tester.drag(scroll, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(first).dy, closeTo(top, 1));
      await tester.scrollUntilVisible(
        second,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.drag(scroll, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(second).dy, closeTo(top, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list uses ledger rows with balances and remains readable on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const RecordsPage()));
      await tester.pumpAndSettle();
      expect(find.byType(GlassCard), findsNothing);
      expect(find.byType(TransactionRecordRow), findsNWidgets(3));
      expect(find.text('Balance after'), findsNWidgets(3));
      expect(
        tester
            .widgetList<Text>(
              find.byKey(const ValueKey('transaction-balance-null')),
            )
            .map((text) => text.data),
        containsAll([state.money.full(-7000), state.money.full(-15000)]),
      );
      state.selectAccount('bank');
      await tester.pumpAndSettle();
      expect(find.byType(TransactionRecordRow), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('transaction-balance-null')),
            )
            .data,
        state.money.full(-15000),
      );
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      expect(find.text('Edit record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'record notes wrap in full and account badges replace transaction type badges',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const note =
          'Shared lunch and groceries for the family gathering, including drinks and snacks, paid from the everyday account.';
      final txn = await state.addTxn(
        Txn(
          date: DateTime(DateTime.now().year, DateTime.now().month, 20),
          amountMinor: 10000,
          type: TxType.income,
          note: note,
          createdAt: 6,
        ),
      );
      for (final page in [
        const RecordsPage(),
        EntryTile(txn: txn, onTap: () {}),
      ]) {
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text(note));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.softWrap, isTrue);
        expect(tester.getSize(find.text(note)).height, greaterThan(40));
        final noteRect = tester.getRect(find.text(note));
        final amountRect = tester.getRect(
          find.text(state.money.signed(txn.signed)),
        );
        expect(noteRect.right, lessThan(amountRect.left));
        expect(noteRect.top, closeTo(amountRect.top, 1));
        final badge = find.descendant(
          of: find.ancestor(
            of: find.text(note),
            matching: find.byType(TransactionRecordDetails),
          ),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is AccountBadge && widget.account.id == txn.accountId,
          ),
        );
        final timeRect = tester.getRect(find.text(fmtTime(txn.date)));
        final badgeRect = tester.getRect(badge);
        expect(badgeRect.left, greaterThan(timeRect.right));
        expect(badgeRect.center.dy, closeTo(timeRect.center.dy, 1));
        expect(badgeRect.top, greaterThan(noteRect.bottom));
        if (page is RecordsPage) {
          final balanceRect = tester.getRect(
            find.byKey(ValueKey('transaction-balance-${txn.id}')),
          );
          expect(noteRect.right, lessThan(balanceRect.left));
          expect(balanceRect.top, greaterThan(noteRect.bottom));
          final details = find.ancestor(
            of: find.text(note),
            matching: find.byType(TransactionRecordDetails),
          );
          final balanceLabel = find.descendant(
            of: details,
            matching: find.text('Balance after'),
          );
          expect(tester.getTopLeft(balanceLabel).dy, closeTo(badgeRect.top, 1));
        }
        expect(find.byType(TransactionTypeBadge), findsNothing);
        expect(find.byIcon(Icons.south_west_rounded), findsNothing);
        expect(find.byIcon(Icons.north_east_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'report labels open a month and year picker and update the range',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in [
        const CalendarPage(),
        const RecordsPage(),
        const InsightsPage(),
      ]) {
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(PeriodNavigator),
                matching: find.text(fmtMonth(DateTime.now())),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Select month and year'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('picker-month')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('June').last);
        await tester.tap(find.text('June').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<ReportExport>(find.byType(ReportExport)).from,
          DateTime(DateTime.now().year, 6),
        );
        expect(
          tester.widget<ReportExport>(find.byType(ReportExport)).to,
          DateTime(DateTime.now().year, 6, 30),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('calendar overflow opens account management', (tester) async {
    await tester.pumpWidget(app(const CalendarPage()));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage accounts'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountsPage), findsOneWidget);
  });

  testWidgets(
    'list and insights date filters fit a narrow phone and scope exports',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in [const RecordsPage(), const InsightsPage()]) {
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        expect(find.byType(PeriodNavigator), findsOneWidget);
        expect(find.byTooltip('Current month'), findsOneWidget);
        final initialExport = tester.widget<ReportExport>(
          find.byType(ReportExport),
        );
        expect(
          initialExport.from,
          DateTime(DateTime.now().year, DateTime.now().month),
        );
        expect(
          initialExport.to,
          DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        );
        await tester.tap(
          find.byIcon(Icons.filter_alt_rounded).evaluate().isEmpty
              ? find.byIcon(Icons.filter_alt_outlined)
              : find.byIcon(Icons.filter_alt_rounded),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'All',
          'Today',
          'Current week',
          'Current month',
          'Current year',
          'Custom',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(
          find
              .ancestor(
                of: find.text('Current year'),
                matching: find.byType(CheckedPopupMenuItem<DateFilter>),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final export = tester.widget<ReportExport>(find.byType(ReportExport));
        expect(export.from, DateTime(DateTime.now().year));
        expect(export.to, DateTime(DateTime.now().year, 12, 31));
        expect(find.byType(PeriodNavigator), findsNothing);
        expect(
          find.text('1 Jan – 31 Dec ${DateTime.now().year}'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Current year'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .ancestor(
                of: find.text('All'),
                matching: find.byType(CheckedPopupMenuItem<DateFilter>),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<ReportExport>(find.byType(ReportExport)).from,
          isNull,
        );
        expect(find.text('All dates'), findsOneWidget);
        expect(find.byType(PeriodNavigator), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'non-month filters display their dates instead of month navigation',
    (tester) async {
      final now = dateOnly(DateTime.now());
      final week = startOfWeek(now, state.weekStart);
      final period = ReportPeriod();
      for (final filter in [
        DateFilter.today,
        DateFilter.week,
        DateFilter.custom,
      ]) {
        period.filter = filter;
        period.custom = DateTimeRange(
          start: DateTime(2025, 12, 29),
          end: DateTime(2026, 1, 3),
        );
        await tester.pumpWidget(
          app(
            ReportPeriodBar(
              period: period,
              onChanged: () {},
              trailing: const SizedBox.shrink(),
            ),
          ),
        );
        expect(find.byType(PeriodNavigator), findsNothing);
        final text = tester
            .widget<Text>(find.byKey(const ValueKey('report-date-range')))
            .data!;
        if (filter == DateFilter.today) {
          expect(text, '${fmtShort(now)} ${now.year}');
        } else if (filter == DateFilter.week) {
          expect(
            text,
            contains('${fmtShort(addDays(week, 6))} ${addDays(week, 6).year}'),
          );
        } else {
          expect(text, '29 Dec 2025 – 3 Jan 2026');
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('list and insights browse weeks and reset to the current week', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final start = startOfWeek(DateTime.now(), state.weekStart);
    Future<void> selectWeek() async {
      await tester.tap(find.byIcon(Icons.filter_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<DateFilter> &&
              widget.value == DateFilter.week,
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final page in [const RecordsPage(), const InsightsPage()]) {
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      await selectWeek();
      expect(
        tester.widget<ReportExport>(find.byType(ReportExport)).from,
        start,
      );
      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      final previous = tester.widget<ReportExport>(find.byType(ReportExport));
      expect(previous.from, addDays(start, -7));
      expect(previous.to, addDays(start, -1));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('report-date-range')))
            .data,
        contains(fmtShort(addDays(start, -7))),
      );
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReportExport>(find.byType(ReportExport)).from,
        addDays(start, 7),
      );
      await selectWeek();
      expect(
        tester.widget<ReportExport>(find.byType(ReportExport)).from,
        start,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'monthly remaining is the same before and after a recorded expense',
    (tester) async {
      state.setMonthlyBudget(300000);
      await state.addTxn(
        Txn(
          date: DateTime(2026, 12, 10),
          amountMinor: 100000,
          type: TxType.expense,
          categoryId: 'food',
          createdAt: 4,
        ),
      );
      for (final day in [1, 10, 30]) {
        await tester.pumpWidget(
          app(DateBudgetIndicators(date: DateTime(2026, 12, day))),
        );
        expect(
          find.text('${state.money.full(200000)} remaining'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          closeTo(1 / 3, 0.001),
        );
      }
    },
  );

  testWidgets('calendar fits a narrow phone with budgets and export', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    state.setDailyBudget(10000);
    state.setMonthlyBudget(50000);
    await tester.pumpWidget(app(const CalendarPage()));
    await tester.pumpAndSettle();
    expect(find.byType(ReportExport), findsOneWidget);
    await tester.tap(find.text('10').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Monthly budget:'), findsOneWidget);
    expect(find.byType(DayPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Day details'), findsNothing);
    final back = tester.getCenter(find.byType(BackButton));
    final previous = tester.getCenter(find.byIcon(Icons.chevron_left_rounded));
    expect(back.dx, lessThan(previous.dx));
    expect(back.dy, lessThan(previous.dy));
    expect(back.dy, closeTo(tester.getCenter(find.byTooltip('Search')).dy, 1));
    expect(find.byType(BottomSheet), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPage), findsOneWidget);
  });

  testWidgets('add account is the last option in entry and global pickers', (
    tester,
  ) async {
    for (final field in [
      AccountField(value: kDefaultAccountId, onChanged: (_) {}),
      const AccountSwitcher(),
    ]) {
      await tester.pumpWidget(app(field));
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(dropdown.items!.last.value, '__add_account__');
    }
  });

  testWidgets(
    'list has its own tab and calendar toggles to week in the account row',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const HomeShell()));
      await tester.pumpAndSettle();
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Week'), findsNothing);
      expect(find.byTooltip('Manage accounts'), findsNothing);
      state.selectAccount('bank');
      await tester.pump();
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordsPage), findsOneWidget);
      expect(find.text('Breakfast'), findsNothing);
      expect(find.text('Lunch'), findsOneWidget);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to week'));
      await tester.pumpAndSettle();
      expect(find.byType(WeekPage), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to calendar'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(state.selectedAccountId, 'bank');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'record details show AM/PM and account badges for all account filters',
    (tester) async {
      await tester.pumpWidget(app(const RecordsPage()));
      expect(find.textContaining('Everyday'), findsWidgets);
      state.selectAccount('bank');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(TransactionRecordRow),
          matching: find.byType(AccountBadge),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('3:00 PM'), findsOneWidget);
      final entry = state.recordsInRange(null, null).single;
      await tester.pumpWidget(app(EntryTile(txn: entry, onTap: () {})));
      expect(find.textContaining('Savings'), findsOneWidget);
      expect(find.textContaining('3:00 PM'), findsOneWidget);
    },
  );

  testWidgets('time control retains AM/PM on a device using 24-hour time', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: EntryDateTimeFields(
            value: DateTime(
              DateTime.now().year,
              DateTime.now().month,
              10,
              18,
              33,
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('6:33 PM'), findsOneWidget);
    await tester.tap(
      find
          .ancestor(of: find.text('Time'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
  });

  testWidgets(
    'calendar search keeps content visible and filters the selected account',
    (tester) async {
      await tester.pumpWidget(app(const CalendarPage()));
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
      expect(find.textContaining('Balance in'), findsOneWidget);
      final input = find.byKey(const ValueKey('record-search'));
      await tester.enterText(input, 'Lunch');
      await tester.pump();
      expect(find.byType(EntryTile), findsOneWidget);
      expect(find.textContaining('Balance in'), findsOneWidget);
      state.selectAccount(kDefaultAccountId);
      await tester.pump();
      expect(find.text('No matches'), findsOneWidget);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(find.byType(PageView), findsOneWidget);
    },
  );

  testWidgets(
    'list search updates from the first character and clears back to all records',
    (tester) async {
      await tester.pumpWidget(app(const RecordsPage()));
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('record-search')), 'B');
      await tester.pump();
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsNothing);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget);
    },
  );

  testWidgets(
    'backup busy indicator preserves Settings positions and scroll offset',
    (tester) async {
      final original = FilePickerPlatform.instance;
      final picker = _PendingPicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      await tester.pumpWidget(app(const SettingsPage()));
      final target = find.text('Restore from backup');
      await tester.scrollUntilVisible(target, 300);
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      final offset = position.pixels;
      final location = tester.getTopLeft(target);
      await tester.tap(target);
      await tester.pump();
      expect(position.pixels, offset);
      expect(tester.getTopLeft(target), location);
      picker.picked.complete(null);
      await tester.pumpAndSettle();
      expect(position.pixels, offset);
      expect(tester.getTopLeft(target), location);
      expect(find.textContaining('Drive'), findsNothing);
    },
  );

  testWidgets(
    'Settings keeps its scroll position while a budget keyboard opens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light, Brand.accents.first),
            home: const HomeShell(),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final settingsList = find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      );
      final target = find.text('Monthly budget');
      await tester.scrollUntilVisible(target, 100, scrollable: settingsList);
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(settingsList).position;
      final offset = position.pixels;
      final location = tester.getTopLeft(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(BudgetsPage), findsOneWidget);
      await tester.tap(find.text('Add budget'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(position.pixels, offset);
      await tester.tap(find.text('Cancel'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(position.pixels, offset);
      expect(tester.getTopLeft(target), location);
    },
  );

  test('PDF exports empty reports and multiple pages of records', () async {
    final generated = DateTime(2026, 11, 24, 18, 42);
    final empty = await buildReportPdf(
      state,
      [],
      'Empty month',
      from: DateTime(2026, 11),
      to: DateTime(2026, 11, 30),
      generatedAt: generated,
    );
    expect(ascii.decode(empty.take(5).toList()), '%PDF-');
    final emptyContent = latin1.decode(empty);
    expect(
      emptyContent,
      contains('Data from 1 November 2026 to 30 November 2026'),
    );
    expect(emptyContent, contains('PDF generated at 24 November 2026 6:42 PM'));
    final entries = [for (var i = 0; i < 150; i++) ...state.all];
    final bytes = await buildReportPdf(state, entries, 'Records');
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(empty.length));
    final dates = state.all.map((txn) => txn.date).toList()..sort();
    expect(
      latin1.decode(bytes),
      contains(
        'Data from ${fmtDayLong(dates.first)} to ${fmtDayLong(dates.last)}',
      ),
    );
  });

  test('filtered CSV balances include earlier records in each account', () {
    final day = DateTime(DateTime.now().year, DateTime.now().month, 10);
    final entries = state.recordsInRange(day, day);
    final csv = encodeCsv(
      entries,
      accountName: (id) => state.accountById(id).name,
      balanceAfter: state.balanceAfter,
    );
    // The earlier 20.00 cash expense is outside the exported date range.
    expect(csv, contains('Breakfast,Everyday,Expense,50.00,-70.00'));
    expect(csv, contains('Lunch,Savings,Expense,150.00,-150.00'));
    expect(
      state.buildCsv(),
      contains('Breakfast,Everyday,Expense,50.00,-70.00'),
    );
  });

  test(
    'PDF exports notes longer than a page without limiting their length',
    () async {
      final note = List.filled(
        160,
        'Full transaction details on another line.',
      ).join('\n');
      await state.addTxn(
        Txn(
          date: DateTime(2026, 11, 24, 12),
          amountMinor: 100,
          type: TxType.income,
          note: note,
          createdAt: 100,
        ),
      );
      final entry = state.all.singleWhere((txn) => txn.note == note);
      final bytes = await buildReportPdf(state, [entry], 'Long note');
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(encodeCsv([entry]), contains('"$note"'));
    },
  );
}
