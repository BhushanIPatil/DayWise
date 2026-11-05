import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('occurrence', () {
    test('monthly clamps to short months and recovers', () {
      final start = DateTime(2026, 1, 31);
      expect(occurrence(start, Frequency.monthly, 0), DateTime(2026, 1, 31));
      expect(occurrence(start, Frequency.monthly, 1), DateTime(2026, 2, 28));
      expect(occurrence(start, Frequency.monthly, 2), DateTime(2026, 3, 31));
      expect(occurrence(start, Frequency.monthly, 3), DateTime(2026, 4, 30));
      expect(occurrence(start, Frequency.monthly, 12), DateTime(2027, 1, 31));
      expect(occurrence(DateTime(2027, 1, 31), Frequency.monthly, 1), DateTime(2027, 2, 28));
      expect(occurrence(DateTime(2028, 1, 31), Frequency.monthly, 1), DateTime(2028, 2, 29));
    });

    test('yearly handles 29 Feb', () {
      final start = DateTime(2024, 2, 29);
      expect(occurrence(start, Frequency.yearly, 1), DateTime(2025, 2, 28));
      expect(occurrence(start, Frequency.yearly, 4), DateTime(2028, 2, 29));
    });

    test('daily and weekly cross month ends', () {
      expect(occurrence(DateTime(2026, 1, 30), Frequency.daily, 3), DateTime(2026, 2, 2));
      expect(occurrence(DateTime(2026, 10, 26), Frequency.weekly, 2), DateTime(2026, 11, 9));
    });
  });

  group('dueDates', () {
    final today = DateTime(2026, 4, 10);

    test('back-fills from the start date up to today', () {
      final d = dueDates(start: DateTime(2026, 1, 15), freq: Frequency.monthly, today: today);
      expect(d, [DateTime(2026, 1, 15), DateTime(2026, 2, 15), DateTime(2026, 3, 15)]);
    });

    test('skips what was already generated', () {
      final d = dueDates(
        start: DateTime(2026, 1, 15),
        freq: Frequency.monthly,
        lastGenerated: DateTime(2026, 2, 15),
        today: today,
      );
      expect(d, [DateTime(2026, 3, 15)]);
    });

    test('nothing when the start is in the future', () {
      expect(dueDates(start: DateTime(2026, 5, 1), freq: Frequency.daily, today: today), isEmpty);
    });

    test('includes today', () {
      expect(dueDates(start: today, freq: Frequency.daily, today: today), [today]);
    });

    test('respects the end date', () {
      final d = dueDates(
        start: DateTime(2026, 1, 15),
        freq: Frequency.monthly,
        end: DateTime(2026, 2, 20),
        today: today,
      );
      expect(d, [DateTime(2026, 1, 15), DateTime(2026, 2, 15)]);
    });

    test('is capped', () {
      final d = dueDates(start: DateTime(2000, 1, 1), freq: Frequency.daily, today: today, cap: 50);
      expect(d.length, 50);
    });
  });

  group('rule', () {
    final rule = RecurringRule(
      id: 3,
      type: TxType.expense,
      amountMinor: 1500000,
      categoryId: 'rent',
      note: 'House rent',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 1),
      lastGenerated: DateTime(2026, 3, 1),
      createdAt: 5,
    );

    test('map round trip', () {
      final back = RecurringRule.fromMap(rule.toMap());
      expect(back.id, 3);
      expect(back.amountMinor, 1500000);
      expect(back.frequency, Frequency.monthly);
      expect(back.startDate, DateTime(2026, 1, 1));
      expect(back.endDate, DateTime(2026, 12, 1));
      expect(back.lastGenerated, DateTime(2026, 3, 1));
    });

    test('describe', () {
      expect(describeRule(rule), 'Monthly on the 1st');
      RecurringRule monthlyOn(int day) => RecurringRule(
            type: TxType.expense,
            amountMinor: 1,
            categoryId: 'x',
            frequency: Frequency.monthly,
            startDate: DateTime(2026, 1, day),
            createdAt: 0,
          );
      expect(describeRule(monthlyOn(2)), 'Monthly on the 2nd');
      expect(describeRule(monthlyOn(3)), 'Monthly on the 3rd');
      expect(describeRule(monthlyOn(11)), 'Monthly on the 11th');
      expect(describeRule(monthlyOn(22)), 'Monthly on the 22nd');
    });

    test('nextDue', () {
      expect(nextDue(rule, DateTime(2026, 4, 10)), DateTime(2026, 5, 1));
      expect(nextDue(rule, DateTime(2026, 12, 1)), isNull);
    });
  });
}
