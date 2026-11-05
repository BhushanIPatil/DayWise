import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_service.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'categories_page.dart';
import 'accounts_page.dart';
import 'date_time_fields.dart';
import 'widgets.dart';

/// Add a new entry (pass [date]) or edit an existing one (pass [edit]).
Future<bool?> showEntrySheet(
  BuildContext context, {
  DateTime? date,
  Txn? edit,
  TxType type = TxType.expense,
  String? accountId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EntrySheet(
      date: date ?? DateTime.now(),
      edit: edit,
      type: type,
      accountId:
          accountId ??
          AppScope.read(context).selectedAccountId ??
          kDefaultAccountId,
    ),
  );
}

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    required this.date,
    this.edit,
    this.type = TxType.expense,
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
  String? _catId;
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
      _catId = e.categoryId;
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
      _accountId = widget.accountId;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _newCategory() async {
    final created = await showCategoryEditor(context, _type);
    if (created != null && mounted) setState(() => _catId = created.id);
  }

  Future<void> _save() async {
    if (_saving) return;
    final minor = parseMinor(_amount.text);
    final s = AppScope.read(context);
    if (minor <= 0) return;
    setState(() => _saving = true);
    final cats = s.categoriesFor(_type);
    final catId = (_catId != null && cats.any((c) => c.id == _catId))
        ? _catId!
        : cats.first.id;
    final old = widget.edit;
    final t = Txn(
      id: old?.id,
      date: _date,
      accountId: _accountId,
      amountMinor: minor,
      type: _type,
      categoryId: catId,
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
    final cats = s.categoriesFor(_type);
    final accent = _type == TxType.expense ? Brand.expense : Brand.income;
    final selectedId = (_catId != null && cats.any((c) => c.id == _catId))
        ? _catId
        : cats.first.id;
    final canSave = !_saving && parseMinor(_amount.text) > 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.96,
      ),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: context.cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _typeToggle(accent)),
                if (widget.edit != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Brand.expense,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
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
                      RegExp(r'^\d{0,9}(\.\d{0,2})?$').hasMatch(value.text)
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
                hintText: '0',
                prefixText: money.symbol,
                prefixStyle: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in cats) _catTile(c, c.id == selectedId),
                  _newTile(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AccountField(
              value: _accountId,
              onChanged: (id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 12),
            EntryDateTimeFields(
              value: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)',
                counterText: '',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: canSave ? accentGradient(accent) : null,
                  color: canSave ? null : context.softFill,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
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
          ],
        ),
      ),
    );
  }

  Widget _typeToggle(Color accent) {
    Widget seg(String label, TxType t, Color c) {
      final sel = _type == t;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_type != t) {
              tapHaptic();
              setState(() {
                _type = t;
                _catId = null;
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? c : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: sel ? Colors.white : context.cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          seg('Expense', TxType.expense, Brand.expense),
          seg('Income', TxType.income, Brand.income),
        ],
      ),
    );
  }

  Widget _catTile(Category c, bool selected) {
    final color = c.colorValue;
    return GestureDetector(
      onTap: () {
        tapHaptic();
        setState(() => _catId = c.id);
      },
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? tint(color, 0.16) : context.softFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(c.iconData, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              c.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newTile() {
    return GestureDetector(
      onTap: _newCategory,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.cs.outlineVariant, width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: context.cs.primary, size: 26),
            const SizedBox(height: 6),
            const Text(
              'New',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
