import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/txn.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/amount_text.dart';
import '../widgets/empty_state.dart';
import '../widgets/quick_entry_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TxnType? _type;
  DateTime? _month;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    var items = state.txns;
    if (_type != null) {
      items = items.where((t) => t.type == _type).toList();
    }
    if (_month != null) {
      items = items
          .where((t) =>
              t.date.year == _month!.year && t.date.month == _month!.month)
          .toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items
          .where((t) =>
              t.note.toLowerCase().contains(query) ||
              state.categoryName(t.categoryId).toLowerCase().contains(query))
          .toList();
    }

    var income = 0.0, expense = 0.0;
    for (final t in items) {
      if (t.type == TxnType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    final groups = <String, List<Txn>>{};
    for (final t in items) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entries'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search notes or categories',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    FilterChip(
                      label: const Text('All types'),
                      selected: _type == null,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Income'),
                      selected: _type == TxnType.income,
                      onSelected: (_) =>
                          setState(() => _type = TxnType.income),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Expense'),
                      selected: _type == TxnType.expense,
                      onSelected: (_) =>
                          setState(() => _type = TxnType.expense),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 18),
                      label: Text(
                        _month == null ? 'All months' : monthLabel(_month!),
                      ),
                      onPressed: () => _pickMonth(state),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showQuickEntrySheet(context, initialType: TxnType.income),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long,
              title: 'No entries here',
              message: 'Add a sale or an expense, or change the filters.',
            )
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _Mini(label: 'Income', value: income, color: AppTheme.income),
                      _Mini(
                        label: 'Expense',
                        value: expense,
                        color: AppTheme.expense,
                      ),
                      _Mini(
                        label: 'Net',
                        value: income - expense,
                        color: Theme.of(context).colorScheme.primary,
                        signed: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                          child: Text(
                            dayLabel(entry.value.first.date),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              for (var i = 0; i < entry.value.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                TransactionTile(
                                  txn: entry.value[i],
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionScreen(
                                        existing: entry.value[i],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _pickMonth(AppState state) async {
    final months = state.recentMonths(18).reversed.toList();
    final picked = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All months'),
              trailing: _month == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
            for (final m in months)
              ListTile(
                title: Text(monthLabel(m)),
                trailing: _month != null &&
                        _month!.year == m.year &&
                        _month!.month == m.month
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _month = picked is DateTime ? picked : null);
  }
}

class _Mini extends StatelessWidget {
  const _Mini({
    required this.label,
    required this.value,
    required this.color,
    this.signed = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 2),
          AmountText(
            value,
            signed: signed,
            color: color,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
