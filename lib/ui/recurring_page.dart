import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/recurrence.dart';
import '../state/app_state.dart';
import 'widgets.dart';
import 'accounts_page.dart';
import 'date_time_fields.dart';

/// Settings -> Recurring entries: rent, EMI, salary, subscriptions...
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    AppState s,
    RecurringRule r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop this rule?'),
        content: const Text(
          'Entries it already created stay in your calendar. No new ones will be added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop rule'),
          ),
        ],
      ),
    );
    if (ok == true) await s.deleteRule(r);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final rules = s.rules;
    final today = dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring entries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await showRuleEditor(context);
          if (saved == true && context.mounted) {
            showSnack(context, 'Rule saved. Entries due so far were added.');
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New rule'),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          rules.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.event_repeat_rounded,
                    title: 'Nothing repeats yet',
                    subtitle:
                        'Add rent, EMI, salary or a subscription once and DayWise records it for you on every due date.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    for (final r in rules)
                      GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        child: Row(
                          children: [
                            CategoryBubble(
                              category: s.categoryById(r.categoryId),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.note.isNotEmpty
                                        ? r.note
                                        : s.categoryById(r.categoryId).name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${describeRule(r)}${r.endDate != null ? ' · until ${fmtShort(r.endDate!)}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.cs.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${s.accountById(r.accountId).name} · ${TimeOfDay(hour: r.timeMinutes ~/ 60, minute: r.timeMinutes % 60).format(context)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.cs.onSurfaceVariant,
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final next = nextDue(r, today);
                                      return Text(
                                        next == null
                                            ? 'Ended'
                                            : 'Next: ${fmtDayLong(next)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: context.cs.primary,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              money.signed(
                                r.type == TxType.income
                                    ? r.amountMinor
                                    : -r.amountMinor,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: r.type == TxType.income
                                    ? Brand.income
                                    : Brand.expense,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Stop rule',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _confirmDelete(context, s, r),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ],
      ),
    );
  }
}

Future<bool?> showRuleEditor(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RuleEditor(),
  );
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor();

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  TxType _type = TxType.expense;
  String? _catId;
  Frequency _freq = Frequency.monthly;
  DateTime _start = dateOnly(DateTime.now());
  DateTime? _end;
  String? _accountId;
  int _timeMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Last date',
    );
    if (d != null) setState(() => _end = dateOnly(d));
  }

  Future<void> _save() async {
    final minor = parseMinor(_amount.text.trim());
    if (minor <= 0) return;
    final s = AppScope.read(context);
    final cats = s.categoriesFor(_type);
    final catId = (_catId != null && cats.any((c) => c.id == _catId))
        ? _catId!
        : cats.first.id;
    final rule = RecurringRule(
      type: _type,
      amountMinor: minor,
      categoryId: catId,
      accountId: _accountId ?? s.selectedAccountId ?? kDefaultAccountId,
      timeMinutes: _timeMinutes,
      note: _note.text.trim(),
      frequency: _freq,
      startDate: _start,
      endDate: _end,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await s.addRule(rule);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cats = s.categoriesFor(_type);
    final selectedId = (_catId != null && cats.any((c) => c.id == _catId))
        ? _catId
        : cats.first.id;
    final canSave = parseMinor(_amount.text.trim()) > 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
      ),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'New recurring entry',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TxType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('Expense')),
                  ButtonSegment(value: TxType.income, label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() {
                  _type = v.first;
                  _catId = null;
                }),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Amount',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    s.money.symbol.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AccountField(
              value: _accountId ?? s.selectedAccountId ?? kDefaultAccountId,
              onChanged: (id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 12),
            EntryDateTimeFields(
              value: DateTime(
                _start.year,
                _start.month,
                _start.day,
                _timeMinutes ~/ 60,
                _timeMinutes % 60,
              ),
              onChanged: (date) => setState(() {
                _start = dateOnly(date);
                _timeMinutes = date.hour * 60 + date.minute;
                if (_end != null && _end!.isBefore(_start)) _end = null;
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Name, e.g. House rent (optional)',
                counterText: '',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    avatar: Icon(c.iconData, size: 18, color: c.colorValue),
                    label: Text(c.name),
                    selected: c.id == selectedId,
                    onSelected: (_) => setState(() => _catId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Repeats',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Frequency>(
                showSelectedIcon: false,
                segments: [
                  for (final f in Frequency.values)
                    ButtonSegment(value: f, label: Text(frequencyLabel(f))),
                ],
                selected: {_freq},
                onSelectionChanged: (v) => setState(() => _freq = v.first),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    onLongPress: () => setState(() => _end = null),
                    icon: const Icon(Icons.event_busy_rounded, size: 18),
                    label: Text(
                      _end == null
                          ? 'No end date'
                          : 'Until ${fmtShort(_end!)} ${_end!.year}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              describeRule(
                RecurringRule(
                  type: _type,
                  amountMinor: 1,
                  categoryId: '',
                  frequency: _freq,
                  startDate: _start,
                  createdAt: 0,
                ),
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Entries are created for every due date from the start date up to today, then automatically each time a date arrives '
              '(when you open the app). You can still edit or delete any single entry. Long-press "No end date" to clear an end date.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text(
                  'Save rule',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
