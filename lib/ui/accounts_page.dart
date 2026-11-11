import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';
import 'entry_sheet.dart';

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
          borderRadius: BorderRadius.circular(20),
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
  const AccountSwitcher({super.key, this.viewToggle});
  final Widget? viewToggle;

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
                borderRadius: BorderRadius.circular(20),
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
          IconButton(
            tooltip: 'Manage accounts',
            icon: const Icon(Icons.tune_rounded, size: 21),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AccountsPage()),
            ),
          ),
          ?viewToggle,
        ],
      ),
    );
  }
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final total = s.accounts.fold<int>(
      0,
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
                          Icon(
                            Icons.edit_outlined,
                            size: 19,
                            color: context.cs.onSurfaceVariant,
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
                      const SizedBox(height: 8),
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
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(color: context.cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.money.full(s.accountBalance(accountId)),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'A fresh start',
                  subtitle:
                      'Add your first income or expense for this account.',
                ),
              for (final entry in entries)
                EntryTile(
                  txn: entry,
                  showDate: true,
                  onTap: () => showEntrySheet(context, edit: entry),
                ),
            ],
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
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    final opening = a?.openingBalanceMinor ?? 0;
    _balance = TextEditingController(
      text: opening == 0
          ? ''
          : '${opening < 0 ? '-' : ''}${minorToInput(opening.abs())}',
    );
    _color = a?.color ?? Brand.accents.first.toARGB32();
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
        parseMinor(raw.replaceFirst('-', '')) * (raw.startsWith('-') ? -1 : 1);
    final account = MoneyAccount(
      id:
          widget.account?.id ??
          'account_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      openingBalanceMinor: balance,
      color: _color,
    );
    try {
      await AppScope.read(context).saveAccount(account);
      if (mounted) Navigator.pop(context, account);
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                hintText: 'e.g. HDFC Savings',
                prefixIcon: Icon(Icons.account_balance_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (old, value) =>
                      RegExp(r'^-?\d{0,9}(\.\d{0,2})?$').hasMatch(value.text)
                      ? value
                      : old,
                ),
              ],
              decoration: InputDecoration(
                labelText: 'Opening balance',
                hintText: '0',
                prefixText: '${AppScope.of(context).money.symbol} ',
              ),
            ),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save account'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
