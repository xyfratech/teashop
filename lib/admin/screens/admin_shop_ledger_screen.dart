import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/formatters.dart';
import '../ledger_entry.dart';
import '../license_service.dart';
import '../shop.dart';
import '../supabase_config.dart';
import 'shop_status_chip.dart' show prettyDate;

/// Read-only view of a single shop's cloud ledger, for the admin. Each shop's
/// entries are fetched scoped to its own `shop_id`, so one shop's income /
/// expense history never shows under another.
class AdminShopLedgerScreen extends StatefulWidget {
  const AdminShopLedgerScreen({super.key, required this.shop});

  final Shop shop;

  @override
  State<AdminShopLedgerScreen> createState() => _AdminShopLedgerScreenState();
}

enum _TypeFilter { all, income, expense }

class _AdminShopLedgerScreenState extends State<AdminShopLedgerScreen> {
  late Future<List<LedgerEntry>> _future;
  _TypeFilter _filter = _TypeFilter.all;
  final _money = const Money(SupabaseConfig.currencySymbol);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LedgerEntry>> _load() =>
      context.read<LicenseService>().adminShopEntries(widget.shop.id);

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.shop.name} · entries'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<LedgerEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(message: '${snap.error}', onRetry: _reload);
          }

          final all = snap.data ?? const <LedgerEntry>[];
          final summary = ShopLedgerSummary.of(all);
          final entries = switch (_filter) {
            _TypeFilter.all => all,
            _TypeFilter.income => all.where((e) => e.isIncome).toList(),
            _TypeFilter.expense => all.where((e) => !e.isIncome).toList(),
          };

          final groups = <String, List<LedgerEntry>>{};
          for (final e in entries) {
            final d = e.occurredAt;
            groups.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(e);
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                _SummaryCard(summary: summary, money: _money),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final f in _TypeFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(switch (f) {
                            _TypeFilter.all => 'All',
                            _TypeFilter.income => 'Income',
                            _TypeFilter.expense => 'Expense',
                          }),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(
                      child: Text('This shop has not synced any entries yet.'),
                    ),
                  )
                else if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(child: Text('No entries of this type.')),
                  )
                else
                  for (final group in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                      child: Text(
                        dayLabel(group.value.first.occurredAt),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < group.value.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _EntryTile(entry: group.value[i], money: _money),
                          ],
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.money});

  final ShopLedgerSummary summary;
  final Money money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Metric(
                  label: 'Income',
                  value: money.format(summary.income),
                  color: const Color(0xFF2E7D32),
                ),
                _Metric(
                  label: 'Expense',
                  value: money.format(summary.expense),
                  color: const Color(0xFFC62828),
                ),
                _Metric(
                  label: 'Net',
                  value: money.format(summary.net),
                  color: scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary.entryCount == 0
                  ? 'No entries synced'
                  : '${summary.entryCount} entr${summary.entryCount == 1 ? 'y' : 'ies'}'
                      '${summary.firstEntryAt == null ? '' : ' · ${prettyDate(summary.firstEntryAt!)} – ${prettyDate(summary.lastEntryAt!)}'}',
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.money});

  final LedgerEntry entry;
  final Money money;

  @override
  Widget build(BuildContext context) {
    final color =
        entry.isIncome ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final subtitleBits = <String>[
      timeLabel(entry.occurredAt),
      entry.method[0].toUpperCase() + entry.method.substring(1),
      if (entry.note.isNotEmpty) entry.note,
    ];
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          entry.isIncome ? Icons.south_west : Icons.north_east,
          size: 18,
          color: color,
        ),
      ),
      title: Text(
        entry.productName ?? entry.categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitleBits.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${entry.isIncome ? '+' : '−'} ${money.format(entry.amount)}',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
