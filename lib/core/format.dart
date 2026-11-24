import 'package:intl/intl.dart';

// ---------------------------------------------------------------- dates

String two(int n) => n.toString().padLeft(2, '0');

/// yyyy-MM-dd, used as the storage key for a calendar day.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

/// Parses a yyyy-MM-dd key. Throws [FormatException] for invalid input.
DateTime parseKey(String k) {
  final p = k.split('-');
  if (p.length != 3) throw FormatException('Bad date: $k');
  final y = int.parse(p[0]);
  final m = int.parse(p[1]);
  final d = int.parse(p[2]);
  final dt = DateTime(y, m, d);
  if (dt.year != y || dt.month != m || dt.day != d) {
    throw FormatException('Bad date: $k');
  }
  return dt;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// First day of the week containing [d]. [weekStart] uses DateTime.monday..sunday.
DateTime startOfWeek(DateTime d, int weekStart) {
  final diff = (d.weekday - weekStart + 7) % 7;
  return DateTime(d.year, d.month, d.day - diff);
}

String fmtMonthYear(DateTime d) => DateFormat('MMMM yyyy', 'en_US').format(d);
String fmtMonth(DateTime d) => DateFormat('MMMM', 'en_US').format(d);
String fmtDayLong(DateTime d) => DateFormat('d MMMM yyyy', 'en_US').format(d);
String fmtWeekday(DateTime d) => DateFormat('EEEE', 'en_US').format(d);
String fmtShort(DateTime d) => DateFormat('d MMM', 'en_US').format(d);
String fmtStamp(DateTime d) => DateFormat('yyyyMMdd-HHmm', 'en_US').format(d);
String fmtTime(DateTime d) => DateFormat('h:mm a', 'en_US').format(d);

/// Exact minor units, accepting text from storage and legacy integer values.
BigInt readMinor(Object value) => value is BigInt
    ? value
    : value is int
    ? BigInt.from(value)
    : value is String
    ? BigInt.parse(value)
    : throw const FormatException('Invalid monetary value');

/// A bounded ratio for charts and progress bars, even for very large amounts.
double minorRatio(Object numerator, Object denominator, {bool clamp = true}) {
  final n = readMinor(numerator);
  final d = readMinor(denominator);
  if (n <= BigInt.zero || d <= BigInt.zero) return 0;
  if (clamp && n >= d) return 1;
  final ratio = (n * BigInt.from(1000000) ~/ d).toDouble() / 1000000;
  return ratio.isFinite ? ratio : double.maxFinite;
}

// ------------------------------------------------------------- currency

class Currency {
  const Currency(this.code, this.symbol, this.name, {this.indian = false});
  final String code;
  final String symbol;
  final String name;

  /// true = 12,34,567 grouping (lakh / crore). false = 1,234,567.
  final bool indian;
}

const List<Currency> kCurrencies = [
  Currency('INR', '₹', 'Indian Rupee', indian: true),
  Currency('USD', '\$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('AED', 'AED ', 'UAE Dirham'),
  Currency('SAR', 'SAR ', 'Saudi Riyal'),
  Currency('PKR', 'Rs ', 'Pakistani Rupee', indian: true),
  Currency('BDT', '৳', 'Bangladeshi Taka', indian: true),
  Currency('NPR', 'Rs ', 'Nepalese Rupee', indian: true),
  Currency('LKR', 'Rs ', 'Sri Lankan Rupee'),
  Currency('CAD', 'C\$', 'Canadian Dollar'),
  Currency('AUD', 'A\$', 'Australian Dollar'),
  Currency('SGD', 'S\$', 'Singapore Dollar'),
  Currency('MYR', 'RM ', 'Malaysian Ringgit'),
  Currency('IDR', 'Rp ', 'Indonesian Rupiah'),
  Currency('PHP', '₱', 'Philippine Peso'),
  Currency('JPY', '¥', 'Japanese Yen'),
  Currency('ZAR', 'R ', 'South African Rand'),
  Currency('NGN', '₦', 'Nigerian Naira'),
  Currency('KES', 'KSh ', 'Kenyan Shilling'),
  Currency('EGP', 'E£', 'Egyptian Pound'),
  Currency('TRY', '₺', 'Turkish Lira'),
  Currency('BRL', 'R\$ ', 'Brazilian Real'),
];

Currency currencyByCode(String code) => kCurrencies.firstWhere(
  (c) => c.code == code,
  orElse: () => kCurrencies.first,
);

/// Inserts thousands separators into a string of digits.
String groupDigits(String digits, bool indian) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final size = indian ? 2 : 3;
  final parts = <String>[];
  while (rest.length > size) {
    parts.insert(0, rest.substring(rest.length - size));
    rest = rest.substring(0, rest.length - size);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// Money uses exact minor units (paise / cents), serialized as decimal text.
class MoneyFormat {
  const MoneyFormat(this.currency);
  final Currency currency;

  String get symbol => currency.symbol;
  bool get indian => currency.indian;

  /// 1234550 -> "12,345.50"   (no symbol, no sign)
  String plain(Object minor) {
    final a = readMinor(minor).abs();
    final whole = a ~/ BigInt.from(100);
    final frac = (a % BigInt.from(100)).toInt();
    final w = groupDigits(whole.toString(), indian);
    return frac == 0 ? w : '$w.${two(frac)}';
  }

  /// "₹12,345.50" or "-₹12,345.50"
  String full(Object minor) =>
      '${readMinor(minor).isNegative ? '-' : ''}$symbol${plain(minor)}';

  /// "+₹500" / "-₹500"
  String signed(Object minor) {
    final value = readMinor(minor);
    if (value == BigInt.zero) return '$symbol${plain(0)}';
    return '${value.isNegative ? '-' : '+'}$symbol${plain(value)}';
  }

  /// Short form for tight spaces: 1.2K, 3.4L, 2Cr (Indian) or 1.2K, 3.4M (others). No symbol.
  String compact(Object minor) {
    final v = readMinor(minor).abs();
    if (indian) {
      if (v >= BigInt.from(1000000000)) return '${_t(v, 1000000000)}Cr';
      if (v >= BigInt.from(10000000)) return '${_t(v, 10000000)}L';
      if (v >= BigInt.from(100000)) return '${_t(v, 100000)}K';
      return _t(v, 100);
    }
    if (v >= BigInt.from(100000000000)) return '${_t(v, 100000000000)}B';
    if (v >= BigInt.from(100000000)) return '${_t(v, 100000000)}M';
    if (v >= BigInt.from(100000)) return '${_t(v, 100000)}K';
    return _t(v, 100);
  }

  static String _t(BigInt v, int divisor) {
    final d = BigInt.from(divisor);
    if (v >= d * BigInt.from(100)) {
      return ((v + d ~/ BigInt.two) ~/ d).toString();
    }
    final tenths = (v * BigInt.from(10) + d ~/ BigInt.two) ~/ d;
    final fraction = tenths % BigInt.from(10);
    return fraction == BigInt.zero
        ? '${tenths ~/ BigInt.from(10)}'
        : '${tenths ~/ BigInt.from(10)}.$fraction';
  }
}

/// Parses what the user typed on the keypad ("123", "123.", "123.4", "0.05") to minor units.
BigInt parseMinor(String s) {
  if (s.isEmpty) return BigInt.zero;
  final parts = s.split('.');
  final whole = parts[0].isEmpty ? '0' : parts[0];
  final frac = (parts.length > 1 ? parts[1] : '')
      .padRight(2, '0')
      .substring(0, 2);
  return BigInt.tryParse('$whole$frac') ?? BigInt.zero;
}

/// Inverse of [parseMinor], for pre-filling the keypad when editing.
String minorToInput(Object minor) {
  final value = readMinor(minor);
  final whole = value.abs() ~/ BigInt.from(100);
  final frac = (value.abs() % BigInt.from(100)).toInt();
  final sign = value.isNegative ? '-' : '';
  if (frac == 0) return '$sign$whole';
  var f = two(frac);
  if (f.endsWith('0')) f = f.substring(0, 1);
  return '$sign$whole.$f';
}
