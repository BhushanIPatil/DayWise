import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/date_time_fields.dart';
import 'package:daywise/ui/entry_sheet.dart';
import 'package:daywise/ui/recurring_page.dart';
import 'package:daywise/ui/accounts_page.dart';
import 'package:daywise/ui/transaction_type_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDb extends AppDb {
  final entries = <Txn>[];
  final savedRules = <RecurringRule>[];
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
    final id = rule.id ?? savedRules.length + 1;
    savedRules.removeWhere((r) => r.id == id);
    savedRules.add(rule.copyWith(id: id));
    return id;
  }

  @override
  Future<void> applyRecurring(
    List<Txn> txns,
    Map<int, DateTime> lastGenerated,
  ) async {
    for (final entry in txns) {
      await upsertTxn(entry);
    }
    for (var i = 0; i < savedRules.length; i++) {
      final last = lastGenerated[savedRules[i].id];
      if (last != null) {
        savedRules[i] = savedRules[i].copyWith(lastGenerated: last);
      }
    }
  }

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
      expect(find.byTooltip('Category'), findsNothing);
      expect(find.text('Category'), findsOneWidget);
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
      await tester.enterText(amount, '123456789012345678901234567890.12');
      final note = List.filled(20, 'Long transaction note.').join(' ');
      await tester.enterText(
        find.widgetWithText(TextField, 'Note [Optional]'),
        note,
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save income'));
      await tester.tap(find.text('Save income'));
      await tester.pumpAndSettle();
      expect(db.entries.single.type, TxType.income);
      expect(db.entries.single.categoryId, kDefaultCategoryId);
      expect(db.entries.single.accountId, 'bank');
      expect(db.entries.single.date, selected);
      expect(
        db.entries.single.amountMinor,
        BigInt.parse('12345678901234567890123456789012'),
      );
      expect(db.entries.single.note, note);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expense entry saves and unknown legacy categories fall back to Other',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = _MemoryDb();
      final legacy = Txn(
        id: 7,
        date: DateTime.now(),
        type: TxType.expense,
        amountMinor: 1000,
        categoryId: 'retired-category',
        createdAt: 1,
      );
      db.entries.add(legacy);
      final state = AppState(db, await SharedPreferences.getInstance());
      await state.load();
      addTearDown(state.dispose);
      for (final edit in [null, legacy]) {
        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showEntrySheet(
                      context,
                      type: TxType.expense,
                      edit: edit,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Category'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('entry-amount')),
          '42',
        );
        tester.testTextInput.hide();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(edit == null ? 'Save expense' : 'Update'),
        );
        await tester.tap(find.text(edit == null ? 'Save expense' : 'Update'));
        await tester.pumpAndSettle();
        final saved = db.entries.firstWhere(
          (t) => edit == null ? t.id != legacy.id : t.id == legacy.id,
        );
        expect(saved.amountMinor, BigInt.from(4200));
        expect(saved.type, TxType.expense);
        expect(saved.categoryId, kDefaultCategoryId);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('recurring entry defaults to Other', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final db = _MemoryDb();
    final state = AppState(db, await SharedPreferences.getInstance());
    await state.load();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRuleEditor(context),
                child: const Text('New rule'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New rule'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'New recurring entry'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    final orderedFields = [
      find.byType(AccountField),
      find.byType(TransactionTypeToggle),
      find.byType(EntryDateTimeFields),
      find.byKey(const ValueKey('recurring-amount')),
      find.byType(TextField).last,
      find.text('Repeats'),
    ];
    for (var i = 1; i < orderedFields.length; i++) {
      expect(
        tester.getTopLeft(orderedFields[i - 1]).dy,
        lessThan(tester.getTopLeft(orderedFields[i]).dy),
      );
    }
    expect(
      tester.getTopLeft(find.text('Income')).dx,
      lessThan(tester.getTopLeft(find.text('Expense')).dx),
    );
    expect(
      tester
          .widget<TransactionTypeToggle>(find.byType(TransactionTypeToggle))
          .value,
      TxType.income,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('recurring-amount')))
          .style!
          .color,
      Brand.income,
    );
    expect(find.text('Category'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.ensureVisible(find.text('No end date'));
    await tester.tap(find.text('No end date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Remove end date'));
    await tester.tap(find.byTooltip('Remove end date'));
    await tester.pumpAndSettle();
    expect(find.text('No end date'), findsOneWidget);
    expect(find.byTooltip('Remove end date'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '50');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save rule');
    final raised = tester.getRect(save);
    expect(raised.bottom, lessThanOrEqualTo(740 - 260));
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(save).bottom, greaterThan(raised.bottom));
    await tester.tap(find.text('Save rule'));
    await tester.pumpAndSettle();
    expect(state.rules.single.amountMinor, BigInt.from(5000));
    expect(state.rules.single.type, TxType.income);
    expect(state.rules.single.endDate, isNull);
    expect(state.rules.single.categoryId, kDefaultCategoryId);
    expect(db.entries.single.categoryId, kDefaultCategoryId);
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(
      find
          .ancestor(of: find.text('Date'), matching: find.byType(InkWell))
          .first,
    );
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
    await tester.tap(
      find
          .ancestor(of: find.text('Time'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    final picker = tester.widget<TimePickerDialog>(
      find.byType(TimePickerDialog),
    );
    expect(picker.initialEntryMode, TimePickerEntryMode.input);
    expect(picker.helpText, '');
    expect(find.text('When did it happen?'), findsNothing);
    await tester.tap(find.byIcon(Icons.access_time));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, '9');
    await tester.enterText(fields.last, '15');
    await tester.tap(find.text('AM'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(date, DateTime(2026, 11, 9, 9, 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'save stays above the keyboard and returns to the bottom when it closes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final db = _MemoryDb();
      final state = AppState(db, await SharedPreferences.getInstance());
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
      final save = find
          .ancestor(
            of: find.text('Save income'),
            matching: find.byType(InkWell),
          )
          .first;
      final raised = tester.getRect(save);
      expect(raised.bottom, lessThanOrEqualTo(640 - 260));
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.getRect(save).bottom, greaterThan(raised.bottom));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(db.entries.single.amountMinor, BigInt.from(4200));
      expect(tester.takeException(), isNull);
    },
  );
}
