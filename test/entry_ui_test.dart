import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/date_time_fields.dart';
import 'package:daywise/ui/entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDb extends AppDb {
  final entries = <Txn>[];
  @override
  Future<List<MoneyAccount>> accounts() async => [
    kDefaultAccount,
    const MoneyAccount(id: 'bank', name: 'Savings'),
  ];
  @override
  Future<List<Category>> categories() async => [...kDefaultCategories];
  @override
  Future<List<Txn>> allTxns() async => [...entries];
  @override
  Future<List<RecurringRule>> rules() async => [];
  @override
  Future<int> upsertTxn(Txn t) async {
    final id = t.id ?? entries.length + 1;
    entries.removeWhere((e) => e.id == id);
    entries.add(t.copyWith(id: id));
    return id;
  }
}

void main() {
  testWidgets(
    'entry uses the system decimal keyboard and saves the selected account and time',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final db = _MemoryDb();
      final state = AppState(db, await SharedPreferences.getInstance());
      await state.load();
      state.selectAccount('bank');
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light, Brand.accents.first),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showEntrySheet(context, date: DateTime(2026, 11, 5)),
                  child: const Text('New entry'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('New entry'));
      await tester.pumpAndSettle();
      final amount = find.byKey(const ValueKey('entry-amount'));
      expect(
        tester.widget<TextField>(amount).keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(find.byIcon(Icons.backspace_outlined), findsNothing);
      expect(find.text('5 November 2026'), findsOneWidget);
      final selected = tester
          .widget<EntryDateTimeFields>(find.byType(EntryDateTimeFields))
          .value;
      expect(selected.hour, DateTime.now().hour);
      await tester.enterText(amount, '125.50');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save expense'));
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      expect(db.entries.single.accountId, 'bank');
      expect(db.entries.single.date, selected);
      expect(db.entries.single.amountMinor, 12550);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date and time controls preserve the other selected value', (
    tester,
  ) async {
    var date = DateTime(2026, 11, 5, 14, 37);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark, Brand.accents.first),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => EntryDateTimeFields(
              value: date,
              onChanged: (value) => update(() => date = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('9'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this date'));
    await tester.pumpAndSettle();
    expect(date, DateTime(2026, 11, 9, 14, 37));
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    final picker = tester.element(find.byType(TimePickerDialog));
    Navigator.of(picker).pop(const TimeOfDay(hour: 9, minute: 15));
    await tester.pumpAndSettle();
    expect(date, DateTime(2026, 11, 9, 9, 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact entry scrolls above a system keyboard without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        _MemoryDb(),
        await SharedPreferences.getInstance(),
      );
      await state.load();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light, Brand.accents.first),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showEntrySheet(context),
                  child: const Text('New entry'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('New entry'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byKey(const ValueKey('entry-amount')), '42');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save expense'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
