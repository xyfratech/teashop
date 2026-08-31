import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/context_ext.dart';
import 'empty_state.dart';

/// Quick sale counter. Every active menu item shows at its preset price; tap
/// the steppers to set quantities, watch the running bill pinned at the
/// bottom, then hit the green tick to file the whole order as itemised
/// "Tea Sales" income (one entry per line).
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

  Future<void> _save(AppState state) async {
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
        SnackBar(content: Text('Saved $label to income  ·  $lines')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

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
        // ---- the menu: fills every bit of space above the bill bar ----
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'Nothing on the menu matches "$_query"',
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    for (final p in visible) ...[
                      _ItemCard(
                        name: p.name,
                        rate: p.price,
                        count: _countFor(p.id),
                        onMinus: _countFor(p.id) == 0
                            ? null
                            : () => _bump(p.id, -1),
                        onPlus: () => _bump(p.id, 1),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        // ---- bill bar, pinned to the bottom ----
        _BillBar(
          total: total,
          itemCount: _itemCount,
          busy: _saving,
          onClear: (_itemCount == 0 || _saving) ? null : _clear,
          onSave: (total <= 0 || _saving) ? null : () => _save(state),
        ),
      ],
    );
  }
}

/// A single-row menu line: name (large, highlighted when picked), unit price,
/// and a −/count/+ stepper.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.name,
    required this.rate,
    required this.count,
    required this.onMinus,
    required this.onPlus,
  });

  final String name;
  final double rate;
  final int count;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = context.money;
    final picked = count > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: picked ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: picked ? scheme.primary : scheme.outlineVariant,
          width: picked ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_cafe,
            size: 22,
            color: picked ? scheme.onPrimaryContainer : scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color:
                        picked ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  picked
                      ? '${money.format(rate)} each  ·  ${money.format(rate * count)}'
                      : '${money.format(rate)} each',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: picked
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StepBtn(icon: Icons.remove, onTap: onMinus),
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          _StepBtn(icon: Icons.add, onTap: onPlus, filled: true),
        ],
      ),
    );
  }
}

/// Total on the left, big green tick on the right. Sits at the bottom.
class _BillBar extends StatelessWidget {
  const _BillBar({
    required this.total,
    required this.itemCount,
    required this.busy,
    required this.onClear,
    required this.onSave,
  });

  final double total;
  final int itemCount;
  final bool busy;
  final VoidCallback? onClear;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = context.money;
    final canSave = onSave != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 26),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  money.format(total),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: total > 0 ? AppTheme.income : scheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  itemCount == 0
                      ? 'Tap + to build an order'
                      : '$itemCount item${itemCount == 1 ? '' : 's'} in this order',
                  style: TextStyle(fontSize: 12.5, color: scheme.outline),
                ),
              ],
            ),
          ),
          if (itemCount > 0 && !busy)
            IconButton(
              onPressed: onClear,
              tooltip: 'Clear order',
              icon: Icon(Icons.close, color: scheme.outline),
            ),
          const SizedBox(width: 4),
          // ---- the tick: saves the order to income ----
          SizedBox(
            width: 64,
            height: 64,
            child: Material(
              color: canSave
                  ? AppTheme.income
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSave,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.check,
                          size: 34,
                          color: canSave ? Colors.white : scheme.outline,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final Color bg;
    final Color fg;
    if (!enabled) {
      bg = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
      fg = scheme.outline;
    } else if (filled) {
      bg = AppTheme.income;
      fg = Colors.white;
    } else {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    }

    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 22, color: fg),
        ),
      ),
    );
  }
}
