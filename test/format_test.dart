import 'package:daywise/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMinor / minorToInput', () {
    test('parses keypad input', () {
      expect(parseMinor(''), BigInt.from(0));
      expect(parseMinor('0'), BigInt.from(0));
      expect(parseMinor('123'), BigInt.from(12300));
      expect(parseMinor('123.'), BigInt.from(12300));
      expect(parseMinor('123.4'), BigInt.from(12340));
      expect(parseMinor('123.45'), BigInt.from(12345));
      expect(parseMinor('0.05'), BigInt.from(5));
      expect(parseMinor('.5'), BigInt.from(50));
    });

    test('round trips', () {
      for (final v in [1, 5, 50, 99, 100, 12345, 12340, 99999999999]) {
        expect(parseMinor(minorToInput(v)), BigInt.from(v));
      }
    });

    test('large amounts retain cents beyond the native integer range', () {
      expect(parseMinor('1234567890.12'), BigInt.from(123456789012));
      expect(
        parseMinor('92233720368547758.07'),
        BigInt.from(9223372036854775807),
      );
      expect(
        parseMinor('92233720368547758.08'),
        BigInt.parse('9223372036854775808'),
      );
      expect(
        parseMinor('999999999999999999999999999999.99'),
        BigInt.parse('99999999999999999999999999999999'),
      );
      final huge = '${List.filled(400, '9').join()}.99';
      expect(minorToInput(parseMinor(huge)), huge);
      expect(minorRatio(parseMinor(huge), parseMinor(huge)), 1);
      expect(
        minorRatio(parseMinor(huge), parseMinor(huge) * BigInt.two),
        closeTo(0.5, 0.000001),
      );
    });
  });

  group('groupDigits', () {
    test('indian grouping', () {
      expect(groupDigits('999', true), '999');
      expect(groupDigits('1000', true), '1,000');
      expect(groupDigits('123456', true), '1,23,456');
      expect(groupDigits('12345678', true), '1,23,45,678');
    });
    test('international grouping', () {
      expect(groupDigits('1000', false), '1,000');
      expect(groupDigits('1234567', false), '1,234,567');
      expect(groupDigits('123456', false), '123,456');
    });
  });

  group('MoneyFormat', () {
    const inr = MoneyFormat(Currency('INR', '₹', 'Rupee', indian: true));
    const usd = MoneyFormat(Currency('USD', '\$', 'Dollar'));

    test('full / signed', () {
      expect(inr.full(12345650), '₹1,23,456.50');
      expect(inr.full(-50000), '-₹500');
      expect(inr.signed(50000), '+₹500');
      expect(inr.signed(-50000), '-₹500');
      expect(inr.signed(0), '₹0');
      expect(usd.full(123456789), '\$1,234,567.89');
    });

    test('compact', () {
      expect(inr.compact(50000), '500');
      expect(inr.compact(150000), '1.5K');
      expect(inr.compact(12000000), '1.2L');
      expect(inr.compact(1000000000), '1Cr');
      expect(usd.compact(150000), '1.5K');
      expect(usd.compact(250000000), '2.5M');
    });
  });

  group('dates', () {
    test('keys', () {
      expect(dateKey(DateTime(2026, 3, 7)), '2026-03-07');
      expect(parseKey('2026-03-07'), DateTime(2026, 3, 7));
      expect(() => parseKey('2026-02-31'), throwsFormatException);
      expect(() => parseKey('nope'), throwsFormatException);
    });

    test('startOfWeek', () {
      // 2026-10-29 is a Thursday
      final d = DateTime(2026, 10, 29);
      expect(startOfWeek(d, DateTime.monday), DateTime(2026, 10, 26));
      expect(startOfWeek(d, DateTime.sunday), DateTime(2026, 10, 25));
      expect(startOfWeek(d, DateTime.saturday), DateTime(2026, 10, 24));
    });
  });
}
