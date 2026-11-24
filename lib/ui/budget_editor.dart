import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'accounts_page.dart';

Future<void> showBudgetEditor(
  BuildContext context, {
  required bool monthly,
  String? accountId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _BudgetEditor(monthly: monthly, accountId: accountId),
);

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({required this.monthly, this.accountId});
  final bool monthly;
  final String? accountId;
  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  final controller = TextEditingController();
  late String accountId;
  String? error;
  String get label => widget.monthly ? 'Monthly budget' : 'Daily budget';
  int value(AppState s) => widget.monthly
      ? s.budgetForAccount(accountId).monthlyMinor
      : s.budgetForAccount(accountId).dailyMinor;
  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    accountId = widget.accountId ?? s.selectedAccountId ?? s.defaultAccount.id;
    _fill(s);
  }

  void _fill(AppState s) {
    controller.text = value(s) > 0 ? minorToInput(value(s)) : '';
    error = null;
  }

  void _set(AppState s, int amount) {
    if (widget.monthly) {
      s.setMonthlyBudget(amount, accountId: accountId);
    } else {
      s.setDailyBudget(amount, accountId: accountId);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _delete(AppState s) async {
    if (await deleteAccountBudget(
          context,
          monthly: widget.monthly,
          accountId: accountId,
        ) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return AlertDialog(
      title: Text(label),
      scrollable: true,
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AccountField(
              value: accountId,
              onChanged: (id) => setState(() {
                accountId = id;
                _fill(s);
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('budget-amount'),
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (old, next) =>
                      RegExp(r'^\d{0,9}(\.\d{0,2})?$').hasMatch(next.text)
                      ? next
                      : old,
                ),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Amount',
                prefixText: '${s.money.symbol} ',
                errorText: error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (value(s) > 0)
          TextButton(
            onPressed: () => _delete(s),
            child: const Text('Delete', style: TextStyle(color: Brand.expense)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = parseMinor(controller.text);
            if (amount <= BigInt.zero) {
              setState(() => error = 'Enter an amount greater than zero.');
              return;
            }
            _set(
              s,
              (amount > BigInt.from(99999999999)
                      ? BigInt.from(99999999999)
                      : amount)
                  .toInt(),
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<bool> deleteAccountBudget(
  BuildContext context, {
  required bool monthly,
  required String accountId,
}) async {
  final s = AppScope.read(context);
  final label = monthly ? 'monthly' : 'daily';
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $label budget?'),
      content: Text(
        'Remove the budget for ${s.accountById(accountId).name}? Income and expense records will be kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.expense),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return false;
  if (monthly) {
    s.setMonthlyBudget(0, accountId: accountId);
  } else {
    s.setDailyBudget(0, accountId: accountId);
  }
  return true;
}
