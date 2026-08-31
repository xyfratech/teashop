import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/context_ext.dart';

/// Fast add: just a type toggle + amount (+ optional note). No category picker
/// — a default category is assigned and can be changed later by editing the
/// entry. Returns `true` when an entry was saved.
Future<bool?> showQuickEntrySheet(
  BuildContext context, {
  required TxnType initialType,
  double? amount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuickEntrySheet(initialType: initialType, amount: amount),
  );
}

class _QuickEntrySheet extends StatefulWidget {
  const _QuickEntrySheet({required this.initialType, this.amount});

  final TxnType initialType;
  final double? amount;

  @override
  State<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<_QuickEntrySheet> {
  late TxnType _type = widget.initialType;
  late final TextEditingController _amount = TextEditingController(
    text: widget.amount != null ? _trim(widget.amount!) : '',
  );
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  bool get _amountLocked => widget.amount != null;

  static String _trim(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  double? get _value {
    final d = double.tryParse(_amount.text.trim());
    return (d != null && d > 0) ? d : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = _value;
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<AppState>().addQuickEntry(
          type: _type,
          amount: value,
          note: _note.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final money = context.money;
    final scheme = Theme.of(context).colorScheme;
    final color = _type == TxnType.income ? AppTheme.income : AppTheme.expense;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TxnType>(
            segments: const [
              ButtonSegment(
                value: TxnType.income,
                label: Text('Income'),
                icon: Icon(Icons.south_west),
              ),
              ButtonSegment(
                value: TxnType.expense,
                label: Text('Expense'),
                icon: Icon(Icons.north_east),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 18),
          if (_amountLocked)
            Text(
              money.format(_value ?? 0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            )
          else
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${context.read<AppState>().currency} ',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _add,
            icon: const Icon(Icons.check),
            label: Text(
              _value == null
                  ? 'Add ${_type.label.toLowerCase()}'
                  : (_type == TxnType.income
                      ? 'Add ${money.format(_value!)} in'
                      : 'Pay ${money.format(_value!)} out'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Filed under a default category — tap the entry later to change it.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
