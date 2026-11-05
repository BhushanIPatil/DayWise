import 'dart:math' as math;

import '../core/format.dart';
import 'models.dart';

enum Frequency { daily, weekly, monthly, yearly }

String frequencyLabel(Frequency f) => switch (f) {
  Frequency.daily => 'Daily',
  Frequency.weekly => 'Weekly',
  Frequency.monthly => 'Monthly',
  Frequency.yearly => 'Yearly',
};

/// A template that creates a normal entry every time it falls due.
class RecurringRule {
  const RecurringRule({
    this.id,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    this.accountId = kDefaultAccountId,
    this.timeMinutes = 0,
    this.note = '',
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.lastGenerated,
    required this.createdAt,
  });

  final int? id;
  final TxType type;
  final int amountMinor;
  final String categoryId;
  final String accountId;
  final int timeMinutes;
  final String note;
  final Frequency frequency;
  final DateTime startDate;

  /// Last day (inclusive) the rule may create entries on. null = no end.
  final DateTime? endDate;

  /// Last occurrence that has already been turned into an entry. null = none yet.
  final DateTime? lastGenerated;
  final int createdAt;

  RecurringRule copyWith({int? id, DateTime? lastGenerated}) => RecurringRule(
    id: id ?? this.id,
    type: type,
    amountMinor: amountMinor,
    categoryId: categoryId,
    accountId: accountId,
    timeMinutes: timeMinutes,
    note: note,
    frequency: frequency,
    startDate: startDate,
    endDate: endDate,
    lastGenerated: lastGenerated ?? this.lastGenerated,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap({bool includeId = true}) => {
    if (includeId && id != null) 'id': id,
    'type': type.index,
    'amount_minor': amountMinor,
    'category_id': categoryId,
    'account_id': accountId,
    'time_minutes': timeMinutes,
    'note': note,
    'frequency': frequency.index,
    'start_date': dateKey(startDate),
    'end_date': endDate == null ? null : dateKey(endDate!),
    'last_generated': lastGenerated == null ? null : dateKey(lastGenerated!),
    'created_at': createdAt,
  };

  factory RecurringRule.fromMap(Map<String, Object?> m) {
    final f = (m['frequency'] as num).toInt();
    return RecurringRule(
      id: (m['id'] as num?)?.toInt(),
      type: (m['type'] as num).toInt() == 1 ? TxType.income : TxType.expense,
      amountMinor: (m['amount_minor'] as num).toInt(),
      categoryId: m['category_id'] as String,
      accountId: (m['account_id'] as String?) ?? kDefaultAccountId,
      timeMinutes: (m['time_minutes'] as num?)?.toInt() ?? 0,
      note: (m['note'] as String?) ?? '',
      frequency:
          Frequency.values[f < 0 || f >= Frequency.values.length ? 0 : f],
      startDate: parseKey(m['start_date'] as String),
      endDate: m['end_date'] == null ? null : parseKey(m['end_date'] as String),
      lastGenerated: m['last_generated'] == null
          ? null
          : parseKey(m['last_generated'] as String),
      createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  /// Used to avoid importing the same rule twice.
  String get dupKey =>
      '$accountId|$timeMinutes|${type.index}|$amountMinor|$categoryId|${frequency.index}|${dateKey(startDate)}|$note';
}

/// The n-th occurrence (n = 0 is [start] itself). Month/year rules keep the original
/// day-of-month and clamp it for short months (31 Jan -> 28 Feb -> 31 Mar).
DateTime occurrence(DateTime start, Frequency f, int n) {
  switch (f) {
    case Frequency.daily:
      return DateTime(start.year, start.month, start.day + n);
    case Frequency.weekly:
      return DateTime(start.year, start.month, start.day + 7 * n);
    case Frequency.monthly:
      {
        final total = start.month - 1 + n;
        final y = start.year + total ~/ 12;
        final m = total % 12 + 1;
        final dim = DateTime(y, m + 1, 0).day;
        return DateTime(y, m, math.min(start.day, dim));
      }
    case Frequency.yearly:
      {
        final y = start.year + n;
        final dim = DateTime(y, start.month + 1, 0).day;
        return DateTime(y, start.month, math.min(start.day, dim));
      }
  }
}

/// Dates that are due: after [lastGenerated] (exclusive), up to [today] (inclusive),
/// never after [end]. Capped so a mistyped start date cannot create a flood of entries.
List<DateTime> dueDates({
  required DateTime start,
  required Frequency freq,
  DateTime? end,
  DateTime? lastGenerated,
  required DateTime today,
  int cap = 1000,
}) {
  final out = <DateTime>[];
  for (var n = 0; n < 200000; n++) {
    final d = occurrence(start, freq, n);
    if (d.isAfter(today)) break;
    if (end != null && d.isAfter(end)) break;
    if (lastGenerated == null || d.isAfter(lastGenerated)) {
      out.add(d);
      if (out.length >= cap) break;
    }
  }
  return out;
}

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

/// "Every day", "Every week on Monday", "Monthly on the 5th", "Yearly on 5 March"
String describeRule(RecurringRule r) {
  switch (r.frequency) {
    case Frequency.daily:
      return 'Every day';
    case Frequency.weekly:
      return 'Every week on ${fmtWeekday(r.startDate)}';
    case Frequency.monthly:
      return 'Monthly on the ${_ordinal(r.startDate.day)}';
    case Frequency.yearly:
      return 'Yearly on ${r.startDate.day} ${fmtMonth(r.startDate)}';
  }
}

/// The next date after [today] this rule will create an entry, or null if it has ended.
DateTime? nextDue(RecurringRule r, DateTime today) {
  for (var n = 0; n < 200000; n++) {
    final d = occurrence(r.startDate, r.frequency, n);
    if (r.endDate != null && d.isAfter(r.endDate!)) return null;
    if (d.isAfter(today)) return d;
  }
  return null;
}
