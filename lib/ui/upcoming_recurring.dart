import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';

Future<void> configureUpcomingRecurring(BuildContext context) async {
  final state = AppScope.read(context);
  final days = await showDialog<int>(
    context: context,
    builder: (_) =>
        _UpcomingDaysDialog(initialDays: state.upcomingRecurringDays),
  );
  if (days != null && context.mounted) {
    await state.setUpcomingRecurringDays(days);
  }
}

class _UpcomingDaysDialog extends StatefulWidget {
  const _UpcomingDaysDialog({required this.initialDays});
  final int initialDays;
  @override
  State<_UpcomingDaysDialog> createState() => _UpcomingDaysDialogState();
}

class _UpcomingDaysDialogState extends State<_UpcomingDaysDialog> {
  late final TextEditingController controller;
  String? error;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: '${widget.initialDays}');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Upcoming recurring'),
    content: TextField(
      key: const ValueKey('upcoming-days'),
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(
        labelText: 'Number of days',
        hintText: 'Number of days',
        helperText: 'Show the next 1–365 days, starting tomorrow.',
        helperMaxLines: 2,
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = int.tryParse(controller.text);
          if (value == null || value < 1 || value > 365) {
            setState(() => error = 'Enter a number from 1 to 365.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class UpcomingRecurringSection extends StatelessWidget {
  const UpcomingRecurringSection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final upcoming = s.upcomingRecurring();
    final tomorrow = addDays(dateOnly(DateTime.now()), 1);
    final last = addDays(tomorrow, s.upcomingRecurringDays - 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upcoming recurring',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => configureUpcomingRecurring(context),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text(
                  'Next ${s.upcomingRecurringDays} ${s.upcomingRecurringDays == 1 ? 'day' : 'days'}',
                ),
              ),
            ],
          ),
          Text(
            '${fmtDayLong(tomorrow)}${s.upcomingRecurringDays == 1 ? '' : ' – ${fmtDayLong(last)}'}',
            style: TextStyle(
              fontSize: 11.5,
              color: context.cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recurring income or expenses in this period.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var i = 0; i < upcoming.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TransactionRecordDetails(
                  txn: Txn(
                    date: upcoming[i].date,
                    amountMinor: upcoming[i].rule.amountMinor,
                    type: upcoming[i].rule.type,
                    accountId: upcoming[i].rule.accountId,
                    note: upcoming[i].rule.note,
                    createdAt: 0,
                  ),
                  showDate: true,
                ),
              ),
            ],
        ],
      ),
    );
  }
}
