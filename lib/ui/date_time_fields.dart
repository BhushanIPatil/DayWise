import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Paired, accessible controls that retain the other half of the timestamp.
class EntryDateTimeFields extends StatelessWidget {
  const EntryDateTimeFields({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _date(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var draft = dateOnly(value);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose a date',
                        style: ctx.tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          update(() => draft = dateOnly(DateTime.now())),
                      child: const Text('Today'),
                    ),
                  ],
                ),
                Text(
                  fmtDayLong(draft),
                  style: TextStyle(
                    color: ctx.cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                CalendarDatePicker(
                  key: ValueKey(dateKey(draft)),
                  initialDate: draft,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2099, 12, 31),
                  onDateChanged: (date) => update(() => draft = date),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, draft),
                    child: const Text('Use this date'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && context.mounted) {
      onChanged(
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          value.hour,
          value.minute,
        ),
      );
    }
  }

  Future<void> _time(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      helpText: 'When did it happen?',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: ctx.cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            dialBackgroundColor: ctx.softFill,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && context.mounted) {
      onChanged(
        DateTime(
          value.year,
          value.month,
          value.day,
          picked.hour,
          picked.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 3,
        child: _field(
          context,
          'Date',
          fmtDayLong(value),
          Icons.calendar_month_rounded,
          () => _date(context),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: _field(
          context,
          'Time',
          TimeOfDay.fromDateTime(value).format(context),
          Icons.schedule_rounded,
          () => _time(context),
        ),
      ),
    ],
  );

  Widget _field(
    BuildContext context,
    String label,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) => Material(
    color: context.softFill,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: context.cs.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: context.cs.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}
