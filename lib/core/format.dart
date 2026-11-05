import 'package:intl/intl.dart';

// ---------------------------------------------------------------- dates

String two(int n) => n.toString().padLeft(2, '0');

/// yyyy-MM-dd, used as the storage key for a calendar day.
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

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

Currency currencyByCode(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

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

/// Money is always stored as an integer number of minor units (paise / cents).
class MoneyFormat {
  const MoneyFormat(this.currency);
  final Currency currency;

  String get symbol => currency.symbol;
  bool get indian => currency.indian;

  /// 1234550 -> "12,345.50"   (no symbol, no sign)
  String plain(int minor) {
    final a = minor.abs();
    final whole = a ~/ 100;
    final frac = a % 100;
    final w = groupDigits(whole.toString(), indian);
    return frac == 0 ? w : '$w.${two(frac)}';
  }

  /// "₹12,345.50" or "-₹12,345.50"
  String full(int minor) => '${minor < 0 ? '-' : ''}$symbol${plain(minor)}';

  /// "+₹500" / "-₹500"
  String signed(int minor) {
    if (minor == 0) return '$symbol${plain(0)}';
    return '${minor > 0 ? '+' : '-'}$symbol${plain(minor)}';
  }

  /// Short form for tight spaces: 1.2K, 3.4L, 2Cr (Indian) or 1.2K, 3.4M (others). No symbol.
  String compact(int minor) {
    final v = minor.abs() / 100.0;
    if (indian) {
      if (v >= 1e7) return '${_t(v / 1e7)}Cr';
      if (v >= 1e5) return '${_t(v / 1e5)}L';
      if (v >= 1e3) return '${_t(v / 1e3)}K';
      return _t(v);
    }
    if (v >= 1e9) return '${_t(v / 1e9)}B';
    if (v >= 1e6) return '${_t(v / 1e6)}M';
    if (v >= 1e3) return '${_t(v / 1e3)}K';
    return _t(v);
  }

  static String _t(double v) {
    if (v >= 100) return v.round().toString();
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

/// Parses what the user typed on the keypad ("123", "123.", "123.4", "0.05") to minor units.
int parseMinor(String s) {
  if (s.isEmpty) return 0;
  final parts = s.split('.');
  final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
  var frac = 0;
  if (parts.length > 1 && parts[1].isNotEmpty) {
    final f = parts[1].padRight(2, '0').substring(0, 2);
    frac = int.tryParse(f) ?? 0;
  }
  return whole * 100 + frac;
}

/// Inverse of [parseMinor], for pre-filling the keypad when editing.
String minorToInput(int minor) {
  final whole = minor ~/ 100;
  final frac = minor % 100;
  if (frac == 0) return '$whole';
  var f = two(frac);
  if (f.endsWith('0')) f = f.substring(0, 1);
  return '$whole.$f';
}
