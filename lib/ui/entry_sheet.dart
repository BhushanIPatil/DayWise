import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_service.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'accounts_page.dart';
import 'date_time_fields.dart';
import 'widgets.dart';
import 'transaction_type_toggle.dart';

/// Add a new entry (pass [date]) or edit an existing one (pass [edit]).
Future<bool?> showEntrySheet(
  BuildContext context, {
  DateTime? date,
  Txn? edit,
  TxType type = TxType.income,
  String? accountId,
}) {
  final selectedAccount =
      accountId ??
      AppScope.read(context).selectedAccountId ??
      AppScope.read(context).defaultAccount.id;
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => EntrySheet(
        date: date ?? DateTime.now(),
        edit: edit,
        type: type,
        accountId: selectedAccount,
      ),
    ),
  );
}

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    required this.date,
    this.edit,
    this.type = TxType.income,
    this.accountId = kDefaultAccountId,
  });
  final DateTime date;
  final Txn? edit;
  final TxType type;
  final String accountId;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  late TxType _type;
  late DateTime _date;
  final TextEditingController _amount = TextEditingController();
  late String _accountId;
  bool _saving = false;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _type = e.type;
      _date = e.date;
      _amount.text = minorToInput(e.amountMinor);
      _accountId = e.accountId;
      _note.text = e.note;
    } else {
      _type = widget.type;
      final now = DateTime.now();
      _date = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        now.hour,
        now.minute,
      );
      final s = AppScope.read(context);
      _accountId = s.accounts.any((a) => a.id == widget.accountId)
          ? widget.accountId
          : s.defaultAccount.id;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final minor = parseMinor(_amount.text);
    final s = AppScope.read(context);
    if (minor <= BigInt.zero) return;
    setState(() => _saving = true);
    final old = widget.edit;
    final t = Txn(
      id: old?.id,
      date: _date,
      accountId: _accountId,
      amountMinor: minor,
      type: _type,
      categoryId: old?.categoryId ?? '',
      note: _note.text.trim(),
      createdAt: old?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    try {
      if (old == null) {
        await s.addTxn(t);
      } else {
        await s.updateTxn(t);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Could not save. Please try again.');
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    if (old == null) AdService.instance.onEntrySaved();
  }

  Future<void> _delete() async {
    final old = widget.edit;
    if (old == null) return;
    final s = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await s.deleteTxn(old);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final accent = _type == TxType.expense ? Brand.expense : Brand.income;
    final canSave = !_saving && parseMinor(_amount.text) > BigInt.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit == null ? 'Add record' : 'Edit record'),
        actions: [
          if (widget.edit != null)
            IconButton(
              onPressed: _saving ? null : _delete,
              tooltip: 'Delete record',
              icon: const Icon(Icons.delete_outline_rounded),
              color: Brand.expense,
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: PinnedForm(
          expand: true,
          action: SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canSave ? accentGradient(accent) : null,
                color: canSave ? null : context.softFill,
                borderRadius: BorderRadius.circular(Brand.controlRadius),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Brand.controlRadius),
                  onTap: canSave ? _save : null,
                  child: Center(
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : widget.edit != null
                          ? 'Update'
                          : (_type == TxType.expense
                                ? 'Save expense'
                                : 'Save income'),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: canSave
                            ? Colors.white
                            : context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          contentPadding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AccountField(
                value: _accountId,
                onChanged: (id) => setState(() => _accountId = id),
              ),
              const SizedBox(height: 12),
              TransactionTypeToggle(
                value: _type,
                onChanged: (type) => setState(() => _type = type),
              ),
              const SizedBox(height: 12),
              EntryDateTimeFields(
                value: _date,
                onChanged: (date) => setState(() => _date = date),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('entry-amount'),
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
                  prefixText: money.symbol,
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
            ],
          ),
        ),
      ),
    );
  }
}
