import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/amount_text.dart';
import '../widgets/quick_entry_sheet.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_tile.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final month = state.summaryForMonth(now);
    final today = state.summaryForDay(now);
    final recent = state.txns.take(6).toList();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.shopName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        monthLabel(now),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BalanceCard(balance: state.balance, monthProfit: month.profit),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: "Today's sales",
                    amount: today.income,
                    icon: Icons.today,
                    color: AppTheme.income,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: "Today's spend",
                    amount: today.expense,
                    icon: Icons.remove_circle_outline,
                    color: AppTheme.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Month income',
                    amount: month.income,
                    icon: Icons.trending_up,
                    color: AppTheme.income,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Month expense',
                    amount: month.expense,
                    icon: Icons.trending_down,
                    color: AppTheme.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProfitBanner(profit: month.profit),
            const SectionHeader('Quick actions'),
            const _QuickActions(),
            SectionHeader(
              'Recent entries',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                ),
                child: const Text('See all'),
              ),
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No entries yet.\nAdd your first sale or expense.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.outline),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      TransactionTile(
                        txn: recent[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddTransactionScreen(existing: recent[i]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.monthProfit});

  final double balance;
  final double monthProfit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onCard = scheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, Colors.black, 0.25)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account balance',
            style: TextStyle(color: onCard.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 6),
          AmountText(
            balance,
            color: onCard,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                monthProfit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: onCard,
              ),
              const SizedBox(width: 4),
              Text(
                'This month profit  ',
                style: TextStyle(color: onCard.withValues(alpha: 0.85)),
              ),
              AmountText(
                monthProfit,
                signed: true,
                color: onCard,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfitBanner extends StatelessWidget {
  const _ProfitBanner({required this.profit});

  final double profit;

  @override
  Widget build(BuildContext context) {
    final positive = profit >= 0;
    final color = positive ? AppTheme.income : AppTheme.expense;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(positive ? Icons.savings : Icons.warning_amber, color: color),
          const SizedBox(width: 10),
          Text(
            positive ? 'Month profit' : 'Month loss',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          AmountText(
            profit,
            signed: true,
            color: color,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickAction(
          icon: Icons.add,
          label: 'Add income',
          color: AppTheme.income,
          onTap: () =>
              showQuickEntrySheet(context, initialType: TxnType.income),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          icon: Icons.remove,
          label: 'Add expense',
          color: AppTheme.expense,
          onTap: () =>
              showQuickEntrySheet(context, initialType: TxnType.expense),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          icon: Icons.local_cafe,
          label: 'Quick sale',
          color: Theme.of(context).colorScheme.primary,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductsScreen()),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
