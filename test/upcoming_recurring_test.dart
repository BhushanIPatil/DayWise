import 'package:daywise/core/format.dart';
import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/calendar_page.dart';
import 'package:daywise/ui/upcoming_recurring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDb extends AppDb {
  final schedules = <RecurringRule>[];
  @override
  Future<List<MoneyAccount>> accounts() async => [
    kDefaultAccount,
    const MoneyAccount(id: 'bank', name: 'Savings'),
  ];
  @override
  Future<List<Category>> categories() async => [];
  @override
  Future<List<Txn>> allTxns() async => [];
  @override
  Future<List<RecurringRule>> rules() async => schedules;
}

RecurringRule rule({
  int id = 1,
  required DateTime start,
  Frequency frequency = Frequency.daily,
  TxType type = TxType.expense,
  String accountId = kDefaultAccountId,
  int time = 9 * 60,
  DateTime? end,
  DateTime? last,
  String note = 'Scheduled rent',
}) => RecurringRule(
  id: id,
  type: type,
  amountMinor: 10000,
  accountId: accountId,
  timeMinutes: time,
  frequency: frequency,
  startDate: start,
  endDate: end,
  lastGenerated: last,
  note: note,
  createdAt: 1,
);

void main() {
  test(
    'preview includes all occurrences in the next N days, both types and account filtering',
    () {
      final now = DateTime(2026, 11, 12, 15);
      final rules = [
        rule(start: DateTime(2000), time: 10 * 60),
        rule(
          id: 2,
          start: DateTime(2026, 11, 14),
          frequency: Frequency.weekly,
          type: TxType.income,
          accountId: 'bank',
          time: 8 * 60,
        ),
        rule(id: 3, start: DateTime(2026, 11, 17), frequency: Frequency.weekly),
      ];
      final two = upcomingOccurrences(rules, now: now, days: 2);
      expect(two.map((item) => item.date), [
        DateTime(2026, 11, 13, 10),
        DateTime(2026, 11, 14, 8),
        DateTime(2026, 11, 14, 10),
      ]);
      expect(
        two.map((item) => item.rule.type),
        containsAll([TxType.income, TxType.expense]),
      );
      expect(
        upcomingOccurrences(
          rules,
          now: now,
          days: 2,
          accountId: 'bank',
        ).single.rule.id,
        2,
      );
      final five = upcomingOccurrences(rules, now: now, days: 5);
      expect(five, hasLength(7));
      expect(five.last.date, DateTime(2026, 11, 17, 10));
      expect(upcomingOccurrences(rules, now: now, days: 0), isEmpty);
    },
  );

  test(
    'preview respects end dates, future starts and already generated dates',
    () {
      final now = DateTime(2026, 11, 12);
      final items = upcomingOccurrences(
        [
          rule(start: DateTime(2026, 11, 1), end: now),
          rule(id: 2, start: DateTime(2026, 11, 15)),
          rule(
            id: 3,
            start: DateTime(2026, 11, 1),
            end: DateTime(2026, 11, 14),
            last: DateTime(2026, 11, 13),
          ),
        ],
        now: now,
        days: 2,
      );
      expect(items, hasLength(1));
      expect(items.single.rule.id, 3);
      expect(items.single.date, DateTime(2026, 11, 14, 9));
    },
  );

  test('preview preserves short-month and leap-year scheduling', () {
    final monthly = rule(
      start: DateTime(2026, 1, 31),
      frequency: Frequency.monthly,
    );
    expect(
      upcomingOccurrences(
        [monthly],
        now: DateTime(2026, 2, 26),
        days: 2,
      ).single.date,
      DateTime(2026, 2, 28, 9),
    );
    final yearly = rule(
      start: DateTime(2024, 2, 29),
      frequency: Frequency.yearly,
    );
    expect(
      upcomingOccurrences(
        [yearly],
        now: DateTime(2027, 2, 26),
        days: 2,
      ).single.date,
      DateTime(2027, 2, 28, 9),
    );
    expect(
      upcomingOccurrences(
        [monthly],
        now: DateTime(2026, 12, 30),
        days: 2,
      ).single.date,
      DateTime(2026, 12, 31, 9),
    );
  });

  testWidgets(
    'calendar preview is configurable, persists and never creates records',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = _MemoryDb();
      final today = dateOnly(DateTime.now());
      db.schedules.addAll([
        rule(start: addDays(today, 1)),
        rule(
          id: 2,
          start: addDays(today, 5),
          frequency: Frequency.monthly,
          type: TxType.income,
          accountId: 'bank',
          note: 'Scheduled salary',
        ),
      ]);
      final state = AppState(db, prefs);
      await state.load();
      addTearDown(state.dispose);
      expect(state.upcomingRecurringDays, 2);
      expect(state.upcomingRecurring(), hasLength(2));
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light, Brand.accents.first),
            home: const Scaffold(body: CalendarPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = find.byType(UpcomingRecurringSection).first;
      await Scrollable.ensureVisible(tester.element(preview));
      await tester.pumpAndSettle();
      expect(find.text('Scheduled salary'), findsNothing);
      await tester.tap(find.text('Next 2 days').first);
      await tester.pumpAndSettle();
      final daysField = find.byKey(const ValueKey('upcoming-days'));
      await tester.enterText(daysField, '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a number from 1 to 365.'), findsOneWidget);
      expect(state.upcomingRecurringDays, 2);
      await tester.enterText(daysField, '5');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(state.upcomingRecurringDays, 5);
      expect(state.upcomingRecurring(), hasLength(6));
      expect(find.text('Scheduled salary'), findsOneWidget);
      expect(state.all, isEmpty);
      state.selectAccount('bank');
      await tester.pumpAndSettle();
      expect(state.upcomingRecurring().single.rule.note, 'Scheduled salary');
      expect(find.text('Scheduled rent'), findsNothing);
      final reloaded = AppState(db, prefs);
      await reloaded.load();
      addTearDown(reloaded.dispose);
      expect(reloaded.upcomingRecurringDays, 5);
      expect(tester.takeException(), isNull);
    },
  );
}
