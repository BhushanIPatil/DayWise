import 'dart:async';
import 'dart:convert';

import 'package:daywise/core/format.dart';
import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/data/report.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/accounts_page.dart';
import 'package:daywise/ui/calendar_page.dart';
import 'package:daywise/ui/date_budget_indicators.dart';
import 'package:daywise/ui/date_time_fields.dart';
import 'package:daywise/ui/home_shell.dart';
import 'package:daywise/ui/records_page.dart';
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
      date: DateTime(2026, 11, 10, 9),
      amountMinor: 5000,
      type: TxType.expense,
      categoryId: 'food',
      note: 'Breakfast',
      createdAt: 1,
    ),
    Txn(
      date: DateTime(2026, 11, 10, 15),
      amountMinor: 15000,
      type: TxType.expense,
      categoryId: 'food',
      note: 'Lunch',
      accountId: 'bank',
      createdAt: 2,
    ),
    Txn(
      date: DateTime(2026, 11, 9, 9),
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

  test('export range includes the end day and respects account selection', () {
    final date = DateTime(2026, 11, 10);
    expect(state.recordsInRange(date, date).length, 2);
    state.selectAccount('bank');
    expect(state.recordsInRange(date, date).single.note, 'Lunch');
    expect(state.recordsInRange(null, DateTime(2026, 11, 9)), isEmpty);
  });

  testWidgets('records share date labels and retain notes and account filter', (
    tester,
  ) async {
    await tester.pumpWidget(app(const RecordsPage()));
    expect(find.text(fmtDayLong(DateTime(2026, 11, 10))), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.byType(ReportExport), findsOneWidget);
    state.selectAccount('bank');
    await tester.pump();
    expect(find.text('Breakfast'), findsNothing);
    expect(find.text('Lunch'), findsOneWidget);
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
    'calendar and list toggle shares the account row without another nav tab',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const HomeShell()));
      await tester.pumpAndSettle();
      expect(find.text('List'), findsNothing);
      state.selectAccount('bank');
      await tester.pump();
      await tester.tap(find.byTooltip('Switch to list'));
      await tester.pumpAndSettle();
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Breakfast'), findsNothing);
      expect(find.text('Lunch'), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to calendar'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(state.selectedAccountId, 'bank');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'record details show AM/PM and account names only for All accounts',
    (tester) async {
      await tester.pumpWidget(app(const RecordsPage()));
      expect(find.textContaining('Everyday'), findsWidgets);
      state.selectAccount('bank');
      await tester.pump();
      expect(find.textContaining('Savings'), findsNothing);
      expect(find.textContaining('3:00 PM'), findsOneWidget);
      final entry = state.recordsInRange(null, null).single;
      await tester.pumpWidget(app(EntryTile(txn: entry, onTap: () {})));
      expect(find.textContaining('Savings'), findsNothing);
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
            value: DateTime(2026, 11, 10, 18, 33),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('6:33 PM'), findsOneWidget);
    await tester.tap(find.text('Time'));
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
      expect(find.textContaining('Spent in'), findsOneWidget);
      final input = find.byKey(const ValueKey('record-search'));
      await tester.enterText(input, 'Lunch');
      await tester.pump();
      expect(find.byType(EntryTile), findsOneWidget);
      expect(find.textContaining('Spent in'), findsOneWidget);
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
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(position.pixels, offset);
      await tester.tap(find.text('Cancel'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(position.pixels, offset);
      expect(tester.getTopLeft(target), location);
    },
  );

  test('PDF exports empty reports and multiple pages of records', () async {
    final empty = await buildReportPdf(state, [], 'Empty month');
    expect(ascii.decode(empty.take(5).toList()), '%PDF-');
    final entries = [for (var i = 0; i < 150; i++) ...state.all];
    final bytes = await buildReportPdf(state, entries, 'Records');
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(empty.length));
  });
}
