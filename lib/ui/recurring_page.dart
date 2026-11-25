import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/recurrence.dart';
import '../state/app_state.dart';
import 'widgets.dart';
import 'accounts_page.dart';
import 'categories_page.dart';
import 'date_time_fields.dart';
import 'transaction_type_toggle.dart';

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
        title: const Text('Delete recurring entry?'),
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
            child: const Text('Delete rule'),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TransactionTypeBadge(type: r.type),
                                  const SizedBox(height: 6),
                                  Text(
                                    r.note.isNotEmpty
                                        ? r.note
                                        : (r.type == TxType.income
                                              ? 'Income'
                                              : 'Expense'),
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
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      AccountBadge(
                                        account: s.accountById(r.accountId),
                                      ),
                                      Text(
                                        fmtTime(
                                          DateTime(
                                            2000,
                                            1,
                                            1,
                                            r.timeMinutes ~/ 60,
                                            r.timeMinutes % 60,
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
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
                            PopupMenuButton<String>(
                              tooltip: 'Recurring entry options',
                              onSelected: (action) {
                                if (action == 'edit') {
                                  showRuleEditor(context, edit: r);
                                } else {
                                  _confirmDelete(context, s, r);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit rule'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete rule',
                                    style: TextStyle(color: Brand.expense),
                                  ),
                                ),
                              ],
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

Future<bool?> showRuleEditor(BuildContext context, {RecurringRule? edit}) {
  return Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => _RuleEditor(edit: edit)));
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.edit});
  final RecurringRule? edit;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  TxType _type = TxType.income;
  Frequency _freq = Frequency.monthly;
  DateTime _start = dateOnly(DateTime.now());
  DateTime? _end;
  String? _accountId;
  int _timeMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _categoryId = kDefaultCategoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final old = widget.edit;
    if (old == null) return;
    _type = old.type;
    _categoryId = old.categoryId;
    _freq = old.frequency;
    _start = old.startDate;
    _end = old.endDate;
    _accountId = old.accountId;
    _timeMinutes = old.timeMinutes;
    _amount.text = minorToInput(old.amountMinor);
    _note.text = old.note;
  }

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
    if (d != null && mounted) setState(() => _end = dateOnly(d));
  }

  Future<void> _save() async {
    final minor = parseMinor(_amount.text.trim());
    if (minor <= BigInt.zero || _saving) return;
    setState(() => _saving = true);
    final s = AppScope.read(context);
    final rule = RecurringRule(
      id: widget.edit?.id,
      categoryId: s.categoryById(_categoryId).id,
      lastGenerated: widget.edit?.lastGenerated,
      type: _type,
      amountMinor: minor,
      accountId: _accountId ?? s.selectedAccountId ?? s.defaultAccount.id,
      timeMinutes: _timeMinutes,
      note: _note.text.trim(),
      frequency: _freq,
      startDate: _start,
      endDate: _end,
      createdAt:
          widget.edit?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    try {
      if (widget.edit == null) {
        await s.addRule(rule);
      } else {
        await s.updateRule(rule);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(
          context,
          'Could not save the recurring entry. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final canSave = !_saving && parseMinor(_amount.text.trim()) > BigInt.zero;
    final accent = _type == TxType.expense ? Brand.expense : Brand.income;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.edit == null ? 'New recurring entry' : 'Edit recurring entry',
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: PinnedForm(
          expand: true,
          action: SizedBox(
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
          contentPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountField(
                value: _accountId ?? s.selectedAccountId ?? s.defaultAccount.id,
                onChanged: (id) => setState(() => _accountId = id),
              ),
              const SizedBox(height: 12),
              CategoryField(
                value: _categoryId,
                onChanged: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 12),
              TransactionTypeToggle(
                value: _type,
                onChanged: (type) => setState(() => _type = type),
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
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('recurring-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (old, value) =>
                        RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(value.text)
                        ? value
                        : old,
                  ),
                ],
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: -1,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Amount',
                  hintStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  prefixText: s.money.symbol,
                  prefixStyle: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note [Optional]',
                  hintText: 'Note [Optional]',
                  counterText: '',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 14),
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
                      icon: const Icon(Icons.event_busy_rounded, size: 18),
                      label: Text(
                        _end == null
                            ? 'No end date'
                            : 'Until ${fmtShort(_end!)} ${_end!.year}',
                      ),
                    ),
                  ),
                  if (_end != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove end date',
                      onPressed: () => setState(() => _end = null),
                      icon: const Icon(Icons.clear_rounded),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                describeRule(
                  RecurringRule(
                    type: _type,
                    amountMinor: 1,
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
                widget.edit != null
                    ? 'Changes apply to unrecorded and future occurrences. Existing income and expense records are kept.'
                    : 'Entries are created for every due date from the start date up to today, then automatically each time a date arrives '
                          '(when you open the app). You can still edit or delete any single entry.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
