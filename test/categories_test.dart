import 'dart:io';

import 'package:daywise/core/theme.dart';
import 'package:daywise/data/backup.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/categories_page.dart';
import 'package:daywise/ui/entry_sheet.dart';
import 'package:flutter/material.dart';
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
    directory = await Directory.systemTemp.createTemp('daywise_categories_');
    path = '${directory.path}/test.db';
    db = AppDb(factory: databaseFactoryFfi, path: path);
    SharedPreferences.setMockInitialValues({});
    state = AppState(db, await SharedPreferences.getInstance());
    await state.load();
  });
  tearDown(() async {
    state.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  const food = Category(
    id: 'food',
    name: 'Food',
    icon: 'restaurant',
    color: 0xFFEF6C00,
    type: TxType.expense,
  );

  test(
    'category deletion reassigns records and recurring rules and survives reload',
    () async {
      await state.saveCategory(food);
      final entry = await state.addTxn(
        Txn(
          date: DateTime(2026, 1, 1),
          amountMinor: 100,
          type: TxType.expense,
          categoryId: food.id,
          createdAt: 1,
        ),
      );
      await db.upsertRule(
        RecurringRule(
          type: TxType.expense,
          amountMinor: 100,
          categoryId: food.id,
          frequency: Frequency.monthly,
          startDate: DateTime(2099),
          createdAt: 1,
        ),
      );
      await state.deleteCategory(food.id);
      expect(state.all.single.id, entry.id);
      expect(state.all.single.categoryId, kDefaultCategoryId);
      expect((await db.rules()).single.categoryId, kDefaultCategoryId);
      expect(state.categories.map((c) => c.id), [kDefaultCategoryId]);
      await expectLater(
        state.deleteCategory(kDefaultCategoryId),
        throwsStateError,
      );
      await db.close();
      expect((await db.allTxns()).single.categoryId, kDefaultCategoryId);
    },
  );

  test('v4 migration assigns Other without changing record values', () async {
    await state.saveCategory(food);
    await state.addTxn(
      Txn(
        date: DateTime(2026, 1, 1),
        amountMinor: 12345,
        type: TxType.income,
        categoryId: food.id,
        note: 'Keep this',
        createdAt: 42,
      ),
    );
    await db.close();
    final raw = await databaseFactoryFfi.openDatabase(path);
    await raw.setVersion(4);
    await raw.close();
    final migrated = (await db.allTxns()).single;
    expect(migrated.categoryId, kDefaultCategoryId);
    expect(migrated.amountMinor, BigInt.from(12345));
    expect(migrated.note, 'Keep this');
    expect(migrated.createdAt, 42);
  });

  test(
    'backup restore preserves category appearance and default category',
    () async {
      await state.saveCategory(food);
      await expectLater(
        state.saveCategory(
          const Category(
            id: 'duplicate',
            name: ' food ',
            icon: 'other',
            color: 0,
            type: TxType.expense,
          ),
        ),
        throwsArgumentError,
      );
      final backup = parseBackup(state.buildBackupJson());
      await state.deleteAllData();
      expect(state.categories.single.id, kDefaultCategoryId);
      await state.importBackup(backup, replace: true);
      expect(state.categoryById(food.id).icon, 'restaurant');
      expect(state.categoryById(food.id).color, food.color);
    },
  );

  testWidgets('create, edit and select category for a saved transaction', (
    tester,
  ) async {
    Future<void> waitFor(bool Function() done) async {
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!done() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
    }

    Widget app(Widget child) => AppScope(
      state: state,
      child: MaterialApp(
        key: ValueKey(child.runtimeType),
        theme: buildTheme(Brightness.light, Brand.accents.first),
        home: child,
      ),
    );
    await tester.pumpWidget(app(const CategoriesPage()));
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lunch');
    await tester.tap(find.byTooltip('restaurant'));
    await tester.ensureVisible(find.byTooltip('Colour ffef6c00'));
    await tester.tap(find.byTooltip('Colour ffef6c00'));
    await tester.ensureVisible(find.text('Save category'));
    tester.testTextInput.hide();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save category'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await waitFor(() => state.categories.length == 2);
    expect(state.categories, hasLength(2));
    final category = state.categories.firstWhere((c) => c.name == 'Lunch');
    expect(category.icon, 'restaurant');
    expect(category.color, 0xFFEF6C00);
    await tester.tap(find.byTooltip('Edit Lunch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Meals');
    await tester.ensureVisible(find.text('Save category'));
    tester.testTextInput.hide();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save category'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await waitFor(() => state.categoryById(category.id).name == 'Meals');
    expect(state.categoryById(category.id).name, 'Meals');
    await tester.pumpWidget(app(EntrySheet(date: DateTime(2026, 1, 1))));
    await tester.pumpAndSettle();
    expect(find.text('Other'), findsOneWidget);
    await tester.tap(find.byType(CategoryField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meals'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('entry-amount')), '50');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Meals'), findsOneWidget);
    final field = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byType(CategoryField),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(field.decoration.labelText, 'Category');
    await tester.ensureVisible(find.byType(CategoryField));
    await tester.tap(find.byType(CategoryField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Coffee breaks');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('coffee'));
    await tester.tap(find.byTooltip('coffee'));
    await tester.ensureVisible(find.text('Save category'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Save category'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await waitFor(() => state.categories.any((c) => c.name == 'Coffee breaks'));
    expect(find.text('Coffee breaks'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('entry-amount')))
          .controller!
          .text,
      '50',
    );
    final created = state.categories.firstWhere(
      (c) => c.name == 'Coffee breaks',
    );
    expect(created.icon, 'coffee');
    await tester.ensureVisible(find.text('Save income'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Save income'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await waitFor(() => state.all.isNotEmpty);
    expect(state.all.single.categoryId, created.id);
    expect(tester.takeException(), isNull);
  });
}
