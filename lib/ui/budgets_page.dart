import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'budget_editor.dart';
import 'widgets.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key, required this.monthly});
  final bool monthly;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    int limit(String id) => monthly
        ? s.budgetForAccount(id).monthlyMinor
        : s.budgetForAccount(id).dailyMinor;
    final accounts = s.accounts
        .where((account) => limit(account.id) > 0)
        .toList();
    final today = dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(monthly ? 'Monthly budgets' : 'Daily budgets'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBudgetEditor(context, monthly: monthly),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add budget'),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          if (accounts.isEmpty)
            const Center(
              child: EmptyState(
                icon: Icons.savings_outlined,
                title: 'No budgets yet',
                subtitle: 'Add a spending limit for an account.',
              ),
            )
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: accounts.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final account = accounts[index];
                final budget = limit(account.id);
                final spent = s
                    .transactionsForAccount(account.id)
                    .where(
                      (txn) =>
                          !txn.isIncome &&
                          (monthly
                              ? txn.date.year == today.year &&
                                    txn.date.month == today.month
                              : sameDay(txn.date, today)),
                    )
                    .fold<BigInt>(
                      BigInt.zero,
                      (sum, txn) => sum + txn.amountMinor,
                    );
                final over = spent > BigInt.from(budget);
                final color = over ? Brand.expense : Brand.income;
                return GlassCard(
                  onTap: () => showBudgetEditor(
                    context,
                    monthly: monthly,
                    accountId: account.id,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AccountBadge(account: account),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Budget options for ${account.name}',
                            onSelected: (action) {
                              if (action == 'edit') {
                                showBudgetEditor(
                                  context,
                                  monthly: monthly,
                                  accountId: account.id,
                                );
                              } else {
                                deleteAccountBudget(
                                  context,
                                  monthly: monthly,
                                  accountId: account.id,
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit budget'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete budget',
                                  style: TextStyle(color: Brand.expense),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.money.full(budget),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        monthly ? 'Monthly limit' : 'Daily limit',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: minorRatio(spent, budget),
                        minHeight: 4,
                        color: color,
                        backgroundColor: context.softFill,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Spent ${s.money.full(spent)} ${monthly ? 'this month' : 'today'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        over
                            ? 'Over budget by ${s.money.full(spent - BigInt.from(budget))}'
                            : '${s.money.full(BigInt.from(budget) - spent)} remaining',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
