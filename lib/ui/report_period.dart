import 'package:flutter/material.dart';

import '../core/format.dart';
import '../state/app_state.dart';
import 'widgets.dart';

Future<DateTime?> showMonthYearPicker(BuildContext context, DateTime initial) {
  var month = initial.month;
  var year = initial.year.clamp(2000, 2099);
  return showDialog<DateTime>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Select month and year'),
        content: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButton<int>(
                key: const ValueKey('picker-month'),
                value: month,
                isExpanded: true,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(fmtMonth(DateTime(2000, m))),
                    ),
                ],
                onChanged: (value) => setState(() => month = value!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButton<int>(
                key: const ValueKey('picker-year'),
                value: year,
                isExpanded: true,
                items: [
                  for (var y = 2000; y <= 2099; y++)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (value) => setState(() => year = value!),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, DateTime(year, month)),
            child: const Text('Select'),
          ),
        ],
      ),
    ),
  );
}

enum DateFilter {
  all('All'),
  today('Today'),
  week('Current week'),
  month('Current month'),
  year('Current year'),
  custom('Custom');

  const DateFilter(this.label);
  final String label;
}

class ReportPeriod {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateFilter? filter = DateFilter.month;
  DateTimeRange? custom;
  int weekOffset = 0;
  int dayOffset = 0;
  int yearOffset = 0;

  void move(int offset) {
    switch (filter) {
      case DateFilter.today:
        dayOffset += offset;
        return;
      case DateFilter.week:
        weekOffset += offset;
        return;
      case DateFilter.year:
        yearOffset += offset;
        return;
      default:
        break;
    }
    month = DateTime(month.year, month.month + offset);
    filter = null;
  }

  DateTimeRange? range(int weekStart) {
    final now = dateOnly(DateTime.now());
    switch (filter) {
      case DateFilter.all:
        return null;
      case DateFilter.today:
        final day = addDays(now, dayOffset);
        return DateTimeRange(start: day, end: day);
      case DateFilter.week:
        final start = addDays(startOfWeek(now, weekStart), weekOffset * 7);
        return DateTimeRange(start: start, end: addDays(start, 6));
      case DateFilter.year:
        return DateTimeRange(
          start: DateTime(now.year + yearOffset),
          end: DateTime(now.year + yearOffset, 12, 31),
        );
      case DateFilter.custom:
        return custom;
      case DateFilter.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1, 0),
        );
      case null:
        return DateTimeRange(
          start: month,
          end: DateTime(month.year, month.month + 1, 0),
        );
    }
  }
}

/// A single compact row shared by the monthly reports.
class ReportPeriodBar extends StatelessWidget {
  const ReportPeriodBar({
    super.key,
    required this.period,
    required this.onChanged,
    required this.trailing,
  });
  final ReportPeriod period;
  final VoidCallback onChanged;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final range = period.range(AppScope.of(context).weekStart);
    final monthly = period.filter == null || period.filter == DateFilter.month;
    final unit = switch (period.filter) {
      DateFilter.today => 'day',
      DateFilter.week => 'week',
      DateFilter.year => 'year',
      _ => null,
    };
    String fullDate(DateTime date) => '${fmtShort(date)} ${date.year}';
    final label = range == null
        ? 'All dates'
        : sameDay(range.start, range.end)
        ? fullDate(range.start)
        : '${range.start.year == range.end.year ? fmtShort(range.start) : fullDate(range.start)} – ${fullDate(range.end)}';
    return Row(
      children: [
        Expanded(
          child: monthly
              ? PeriodNavigator(
                  title: fmtMonth(period.month),
                  subtitle: '${period.month.year}',
                  onSelect: () async {
                    final month = await showMonthYearPicker(
                      context,
                      period.month,
                    );
                    if (month == null || !context.mounted) return;
                    period.month = month;
                    period.filter = null;
                    onChanged();
                  },
                  onPrev: () {
                    period.move(-1);
                    onChanged();
                  },
                  onNext: () {
                    period.move(1);
                    onChanged();
                  },
                )
              : unit != null
              ? Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous $unit',
                      icon: const Icon(Icons.chevron_left_rounded, size: 30),
                      onPressed: () {
                        period.move(-1);
                        onChanged();
                      },
                    ),
                    Expanded(
                      child: Text(
                        label,
                        key: const ValueKey('report-date-range'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: periodLabelStyle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next $unit',
                      icon: const Icon(Icons.chevron_right_rounded, size: 30),
                      onPressed: () {
                        period.move(1);
                        onChanged();
                      },
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    key: const ValueKey('report-date-range'),
                    maxLines: 2,
                    style: periodLabelStyle,
                  ),
                ),
        ),
        PopupMenuButton<DateFilter>(
          tooltip: period.filter?.label ?? 'Date filter',
          icon: Icon(
            period.filter == null
                ? Icons.filter_alt_outlined
                : Icons.filter_alt_rounded,
          ),
          initialValue: period.filter,
          itemBuilder: (_) => [
            for (final filter in DateFilter.values)
              CheckedPopupMenuItem(
                value: filter,
                checked: period.filter == filter,
                child: Text(filter.label),
              ),
          ],
          onSelected: (filter) async {
            if (filter == DateFilter.custom) {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2099, 12, 31),
                initialDateRange: period.custom,
              );
              if (range == null || !context.mounted) return;
              period.custom = range;
              period.month = DateTime(range.start.year, range.start.month);
            } else if (filter != DateFilter.all) {
              final now = DateTime.now();
              period.month = DateTime(now.year, now.month);
            }
            period.filter = filter;
            period.weekOffset = 0;
            period.dayOffset = 0;
            period.yearOffset = 0;
            onChanged();
          },
        ),
        trailing,
      ],
    );
  }
}
