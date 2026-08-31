import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/context_ext.dart';
import '../utils/formatters.dart';
import 'empty_state.dart';

/// Quick sale counter. Every active menu item shows at its preset price; tap
/// the steppers to set quantities, watch the running bill, then post the whole
/// order to the account as itemised "Tea Sales" income (one entry per line).
class ChaiSnackCounter extends StatefulWidget {
  const ChaiSnackCounter({super.key});

  @override
  State<ChaiSnackCounter> createState() => _ChaiSnackCounterState();
}

class _ChaiSnackCounterState extends State<ChaiSnackCounter> {
  /// productId -> quantity. Only holds rows with a count of 1 or more.
  final Map<String, int> _qty = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _countFor(String id) => _qty[id] ?? 0;

  int get _itemCount => _qty.values.fold(0, (s, n) => s + n);

  void _bump(String id, int delta) {
    setState(() {
      final next = (_countFor(id) + delta).clamp(0, 999);
      if (next == 0) {
        _qty.remove(id);
      } else {
        _qty[id] = next;
      }
    });
  }

  void _clear() => setState(_qty.clear);

  double _total(List<Product> products) {
    var t = 0.0;
    for (final p in products) {
      t += p.price * _countFor(p.id);
    }
    return t;
  }

  Future<void> _submit(AppState state) async {
    if (_saving || _qty.isEmpty) return;

    // Snapshot the human summary before the counts are wiped.
    final lines = state.products
        .where((p) => _countFor(p.id) > 0)
        .map((p) => '${_countFor(p.id)}× ${p.name}')
        .join(' · ');

    setState(() => _saving = true);
    double total;
    try {
      total = await state.recordSaleBatch(Map<String, int>.of(_qty));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;

    setState(_qty.clear);
    final label = context.money.format(total);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Added $label to account  ·  $lines')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final money = context.money;

    final active = state.products.where((p) => p.active).toList();

    if (active.isEmpty) {
      return const EmptyState(
        icon: Icons.local_cafe_outlined,
        title: 'No menu items yet',
        message: 'Add your teas and snacks with their prices on the Menu tab, '
            'then come back here to ring up an order.',
      );
    }

    final visible = _query.isEmpty
        ? active
        : active.where((p) => p.name.toLowerCase().contains(_query)).toList();
    final showSearch = active.length > 6;
    final total = _total(active);

    return Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search menu',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _searchCtrl.clear,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'Nothing on the menu matches "$_query"',
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = visible[i];
                    final count = _countFor(p.id);
                    return _ItemRow(
                      name: p.name,
                      rate: p.price,
                      count: count,
                      lineTotal: p.price * count,
                      onMinus: count == 0 ? null : () => _bump(p.id, -1),
                      onPlus: () => _bump(p.id, 1),
                    );
                  },
                ),
        ),
        _BillBar(
          total: total,
          itemCount: _itemCount,
          money: money,
          busy: _saving,
          onClear: (_itemCount == 0 || _saving) ? null : _clear,
          onAdd: (total <= 0 || _saving) ? null : () => _submit(state),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.name,
    required this.rate,
    required this.count,
    required this.lineTotal,
    required this.onMinus,
    required this.onPlus,
  });

  final String name;
  final double rate;
  final int count;
  final double lineTotal;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = context.money;
    final selected = count > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.25)
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_cafe, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${money.format(rate)} each',
                  style: TextStyle(color: scheme.outline)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StepBtn(icon: Icons.remove, onTap: onMinus),
              Expanded(
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              _StepBtn(icon: Icons.add, onTap: onPlus),
              const SizedBox(width: 10),
              SizedBox(
                width: 84,
                child: Text(
                  selected ? money.format(lineTotal) : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onSurface : scheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillBar extends StatelessWidget {
  const _BillBar({
    required this.total,
    required this.itemCount,
    required this.money,
    required this.busy,
    required this.onClear,
    required this.onAdd,
  });

  final double total;
  final int itemCount;
  final Money money;
  final bool busy;
  final VoidCallback? onClear;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                money.format(total),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: total > 0 ? AppTheme.income : scheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              itemCount == 0
                  ? 'Tap + to build an order'
                  : '$itemCount item${itemCount == 1 ? '' : 's'} in this order',
              style: TextStyle(color: scheme.outline),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: onClear,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Clear'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    busy ? 'Adding…' : 'Add ${money.format(total)} to account',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.income,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? scheme.onPrimaryContainer : scheme.outline,
          ),
        ),
      ),
    );
  }
}
