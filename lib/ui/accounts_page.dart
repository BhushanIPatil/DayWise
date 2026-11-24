import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';
import 'entry_sheet.dart';
import 'transaction_list.dart';
import 'date_time_fields.dart';

/// The same account control is used when recording entries and recurring rules.
class AccountField extends StatelessWidget {
  const AccountField({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Account',
        prefixIcon: Icon(Icons.account_balance_rounded),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(Brand.controlRadius),
          items: [
            for (final a in s.accounts)
              DropdownMenuItem(
                value: a.id,
                child: Text(a.name, overflow: TextOverflow.ellipsis),
              ),
            const DropdownMenuItem(
              value: '__add_account__',
              child: Text('+ Add account'),
            ),
          ],
          onChanged: (id) async {
            if (id == '__add_account__') {
              final account = await showAccountEditor(context);
              if (account != null && context.mounted) onChanged(account.id);
            } else if (id != null) {
              onChanged(id);
            }
          },
        ),
      ),
    );
  }
}

class AccountSwitcher extends StatelessWidget {
  const AccountSwitcher({super.key, this.viewToggle, this.actions});
  final Widget? viewToggle;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 20,
            color: context.cs.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: s.selectedAccountId ?? '',
                isExpanded: true,
                borderRadius: BorderRadius.circular(Brand.controlRadius),
                style: context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All accounts'),
                  ),
                  for (final a in s.accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                  const DropdownMenuItem(
                    value: '__add_account__',
                    child: Text('+ Add account'),
                  ),
                ],
                onChanged: (id) async {
                  if (id == '__add_account__') {
                    final account = await showAccountEditor(context);
                    if (account != null && context.mounted) {
                      s.selectAccount(account.id);
                    }
                  } else {
                    s.selectAccount(id == '' ? null : id);
                  }
                },
              ),
            ),
          ),
          ?viewToggle,
          ?actions,
        ],
      ),
    );
  }
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    MoneyAccount account,
  ) async {
    final s = AppScope.read(context);
    if (s.accounts.length <= 1) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep at least one account'),
          content: const Text(
            'Add another account before deleting this one so you can continue recording income and expenses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final records = s.transactionsForAccount(account.id).length;
    final rules = s.rules.where((rule) => rule.accountId == account.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${account.name}?'),
        content: Text(
          'This permanently deletes this account'
          '${account.openingBalanceMinor != BigInt.zero ? ', its opening balance of ${s.money.full(account.openingBalanceMinor)}' : ''}, '
          '$records income and expense ${records == 1 ? 'record' : 'records'}, and '
          '$rules recurring ${rules == 1 ? 'rule' : 'rules'}.\n\n'
          'Your totals will update. This cannot be undone. Save a backup first if you may need this data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await s.deleteAccount(account.id);
      if (context.mounted) showSnack(context, '${account.name} deleted.');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Could not delete this account. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final total = s.accounts.fold<BigInt>(
      BigInt.zero,
      (sum, a) => sum + s.accountBalance(a.id),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Your accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              GlassCard(
                gradient: accentGradient(context.cs.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL BALANCE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.money.full(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A clearer picture of your money, together.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Track each bank account in one place. Balances reflect your opening balance and recorded entries.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              for (final a in s.accounts) ...[
                GlassCard(
                  onTap: () => showAccountEditor(context, account: a),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: tint(Color(a.color), .14),
                            child: Icon(
                              Icons.account_balance_rounded,
                              color: Color(a.color),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              a.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Options for ${a.name}',
                            onSelected: (action) {
                              if (action == 'edit') {
                                showAccountEditor(context, account: a);
                              } else {
                                _confirmDelete(context, a);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit account'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete account',
                                  style: TextStyle(color: Brand.expense),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        s.money.full(s.accountBalance(a.id)),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Income ${s.money.full(s.accountTotals(a.id).income)}',
                            style: const TextStyle(
                              color: Brand.income,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Expenses ${s.money.full(s.accountTotals(a.id).expense)}',
                            style: const TextStyle(
                              color: Brand.expense,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (a.openingBalanceMinor != BigInt.zero)
                        const SizedBox(height: 8),
                      if (a.openingBalanceMinor != BigInt.zero)
                        Text(
                          'Opening balance ${s.money.full(a.openingBalanceMinor)}',
                          style: TextStyle(
                            color: context.cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _AccountActivity(accountId: a.id),
                          ),
                        ),
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                        ),
                        label: const Text('View activity'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('Add account'),
                onTap: () => showAccountEditor(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountActivity extends StatelessWidget {
  const _AccountActivity({required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final account = s.accountById(accountId);
    final entries = s.transactionsForAccount(accountId);
    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEntrySheet(context, accountId: accountId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add entry'),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          TransactionList(
            entries: entries,
            bottomPadding: 100,
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _AccountActivitySummary(account: account),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountActivitySummary extends StatelessWidget {
  const _AccountActivitySummary({required this.account});
  final MoneyAccount account;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final totals = s.accountTotals(account.id);
    final balance = s.accountBalance(account.id);
    final balanceColor = balance < BigInt.zero
        ? Brand.expense
        : context.cs.primary;
    Widget metric(String label, BigInt value, Color color, String key) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tint(color, 0.09),
              borderRadius: BorderRadius.circular(Brand.controlRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s.money.full(value),
                    key: ValueKey(key),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: balanceColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              s.money.full(balance),
              key: const ValueKey('account-activity-balance'),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: balanceColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              metric(
                'Income',
                totals.income,
                Brand.income,
                'account-activity-income',
              ),
              const SizedBox(width: 12),
              metric(
                'Expenses',
                totals.expense,
                Brand.expense,
                'account-activity-expenses',
              ),
            ],
          ),
          if (account.openingBalanceMinor != BigInt.zero)
            const SizedBox(height: 12),
          if (account.openingBalanceMinor != BigInt.zero)
            Text(
              'Opening balance ${s.money.full(account.openingBalanceMinor)}',
              style: TextStyle(
                fontSize: 12,
                color: context.cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

Future<MoneyAccount?> showAccountEditor(
  BuildContext context, {
  MoneyAccount? account,
}) => showModalBottomSheet<MoneyAccount>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _AccountEditor(account: account),
);

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({this.account});
  final MoneyAccount? account;
  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late int _color;
  late DateTime _openingDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    final opening = a?.openingBalanceMinor ?? BigInt.zero;
    _balance = TextEditingController(
      text: opening == BigInt.zero
          ? ''
          : '${opening < BigInt.zero ? '-' : ''}${minorToInput(opening.abs())}',
    );
    _color = a?.color ?? Brand.accents.first.toARGB32();
    final now = DateTime.now();
    _openingDate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final raw = _balance.text.trim();
    final balance =
        parseMinor(raw.replaceFirst('-', '')) *
        BigInt.from(raw.startsWith('-') ? -1 : 1);
    final account = MoneyAccount(
      id:
          widget.account?.id ??
          'account_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      openingBalanceMinor: balance,
      color: _color,
    );
    try {
      final s = AppScope.read(context);
      MoneyAccount saved;
      if (widget.account == null) {
        saved = await s.createAccount(account, openingDate: _openingDate);
      } else {
        await s.saveAccount(account);
        saved = s.accountById(account.id);
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ArgumentError
              ? '${e.message}'
              : 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Brand.sheetRadius),
        ),
      ),
      child: PinnedForm(
        action: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save account'),
          ),
        ),
        contentPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account == null ? 'Add an account' : 'Account details',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Give your account a name you recognise.',
              style: TextStyle(color: context.cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Account name',
                hintText: 'Account name',
                prefixIcon: Icon(Icons.account_balance_rounded),
              ),
            ),
            if (widget.account == null ||
                widget.account!.openingBalanceMinor != BigInt.zero) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _balance,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (old, value) =>
                        RegExp(r'^-?\d*(\.\d{0,2})?$').hasMatch(value.text)
                        ? value
                        : old,
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Opening balance',
                  hintText: 'Opening balance [Optional]',
                  prefixText: '${AppScope.of(context).money.symbol} ',
                  helperText:
                      widget.account == null &&
                          parseMinor(_balance.text.replaceFirst('-', '')) >
                              BigInt.zero
                      ? (_balance.text.startsWith('-')
                            ? 'Saved as an expense record.'
                            : 'Saved as an income record.')
                      : null,
                ),
              ),
              if (widget.account == null &&
                  parseMinor(_balance.text.replaceFirst('-', '')) >
                      BigInt.zero) ...[
                const SizedBox(height: 16),
                EntryDateTimeFields(
                  value: _openingDate,
                  onChanged: (date) => setState(() => _openingDate = date),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                for (final color in Brand.accents)
                  IconButton.filledTonal(
                    tooltip:
                        'Account colour ${Brand.accents.indexOf(color) + 1}',
                    style: IconButton.styleFrom(
                      backgroundColor: tint(color, .15),
                      foregroundColor: color,
                    ),
                    onPressed: () => setState(() => _color = color.toARGB32()),
                    icon: Icon(
                      _color == color.toARGB32()
                          ? Icons.check_circle_rounded
                          : Icons.circle,
                    ),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Brand.expense),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
