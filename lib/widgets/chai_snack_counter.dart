import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/context_ext.dart';

/// Preset chai + snack unit prices, pick how many of each with the steppers,
/// see the running bill, and drop the total into the account as one income
/// entry (filed under "Tea Sales").
class ChaiSnackCounter extends StatefulWidget {
  const ChaiSnackCounter({super.key});

  @override
  State<ChaiSnackCounter> createState() => _ChaiSnackCounterState();
}

class _ChaiSnackCounterState extends State<ChaiSnackCounter> {
  int _chai = 0;
  int _snack = 0;
  bool _saving = false;

  static String _plain(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  String get _counts => '$_chai chai · $_snack snack';

  void _reset() => setState(() {
        _chai = 0;
        _snack = 0;
      });

  Future<void> _add(AppState state, double total) async {
    setState(() => _saving = true);
    final parts = <String>[
      if (_chai > 0) '$_chai chai',
      if (_snack > 0) '$_snack snack',
    ];
    await state.addQuickEntry(
      type: TxnType.income,
      amount: total,
      note: parts.join(' · '),
      categoryId: state.incomeCategoryFor('tea').id,
    );
    if (!mounted) return;
    final label = context.money.format(total);
    setState(() {
      _saving = false;
      _chai = 0;
      _snack = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $label · ${parts.join(', ')}')),
    );
  }

  Future<void> _editRates(AppState state) async {
    final chai = TextEditingController(text: _plain(state.chaiRate));
    final snack = TextEditingController(text: _plain(state.snackRate));
    final formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    const kbd = TextInputType.numberWithOptions(decimal: true);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit rates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: chai,
              autofocus: true,
              keyboardType: kbd,
              inputFormatters: formatters,
              decoration: InputDecoration(
                labelText: 'Chai rate',
                prefixText: '${state.currency} ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: snack,
              keyboardType: kbd,
              inputFormatters: formatters,
              decoration: InputDecoration(
                labelText: 'Snack rate',
                prefixText: '${state.currency} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final c = double.tryParse(chai.text.trim());
      final s = double.tryParse(snack.text.trim());
      if (c != null && c > 0) await state.setChaiRate(c);
      if (s != null && s > 0) await state.setSnackRate(s);
    }
    chai.dispose();
    snack.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final money = context.money;
    final scheme = Theme.of(context).colorScheme;

    final chaiTotal = _chai * state.chaiRate;
    final snackTotal = _snack * state.snackRate;
    final total = chaiTotal + snackTotal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              _ItemRow(
                icon: Icons.local_cafe,
                label: 'Chai',
                rate: state.chaiRate,
                count: _chai,
                lineTotal: chaiTotal,
                onMinus: _chai == 0 ? null : () => setState(() => _chai--),
                onPlus: () => setState(() => _chai++),
              ),
              const SizedBox(height: 12),
              _ItemRow(
                icon: Icons.bakery_dining,
                label: 'Snack',
                rate: state.snackRate,
                count: _snack,
                lineTotal: snackTotal,
                onMinus: _snack == 0 ? null : () => setState(() => _snack--),
                onPlus: () => setState(() => _snack++),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _editRates(state),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Edit rates'),
                ),
              ),
            ],
          ),
        ),
        Container(
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
                  Text('Total',
                      style: Theme.of(context).textTheme.titleMedium),
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
                  total == 0 ? 'Tap + to build a bill' : _counts,
                  style: TextStyle(color: scheme.outline),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: (total == 0 || _saving) ? null : _reset,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (total <= 0 || _saving)
                          ? null
                          : () => _add(state, total),
                      icon: const Icon(Icons.check),
                      label: Text('Add ${money.format(total)} to account'),
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
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.icon,
    required this.label,
    required this.rate,
    required this.count,
    required this.lineTotal,
    required this.onMinus,
    required this.onPlus,
  });

  final IconData icon;
  final String label;
  final double rate;
  final int count;
  final double lineTotal;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = context.money;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
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
                  money.format(lineTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
