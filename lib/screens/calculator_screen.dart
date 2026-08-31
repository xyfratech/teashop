import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/calc_engine.dart';
import '../widgets/amount_text.dart';
import '../widgets/chai_snack_counter.dart';
import '../widgets/quick_entry_sheet.dart';

/// A plain 4-function calculator. `=` resolves the expression; the separate
/// green tick drops the current result straight into your account as an entry.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

enum _CalcMode { keypad, chaiSnack }

class _CalculatorScreenState extends State<CalculatorScreen> {
  final CalcEngine _calc = CalcEngine();
  _CalcMode _mode = _CalcMode.keypad;

  double get _value => _calc.value;
  String get _display => _calc.display;
  String get _history => _calc.history;
  bool get _showTick => _calc.showTick;
  bool get _canAdd => _calc.canAdd;

  static String _fmt(double v) => CalcEngine.format(v);

  void _tapDigit(String d) => setState(() => _calc.inputDigit(d));
  void _tapOperator(String op) => setState(() => _calc.setOperator(op));
  void _equals() => setState(() => _calc.equals());
  void _clear() => setState(() => _calc.clear());
  void _backspace() => setState(() => _calc.backspace());
  void _percent() => setState(() => _calc.percent());

  Future<void> _addToAccount() async {
    _equals();
    final value = _value;
    if (value.isNaN || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    final saved = await showQuickEntrySheet(
      context,
      initialType: TxnType.income,
      amount: value,
    );
    if (!mounted) return;
    if (saved == true) {
      _clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount added to your account')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.select<AppState, double>((s) => s.balance);
    final currency = context.select<AppState, String>((s) => s.currency);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SegmentedButton<_CalcMode>(
              segments: const [
                ButtonSegment(
                  value: _CalcMode.keypad,
                  label: Text('Keypad'),
                  icon: Icon(Icons.calculate_outlined),
                ),
                ButtonSegment(
                  value: _CalcMode.chaiSnack,
                  label: Text('Chai & snack'),
                  icon: Icon(Icons.local_cafe_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _mode == _CalcMode.chaiSnack
            ? const ChaiSnackCounter()
            : Column(
          children: [
            // ---- display ----
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Account balance  ',
                          style: TextStyle(color: scheme.outline),
                        ),
                        AmountText(
                          balance,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _history,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, color: scheme.outline),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '$currency ',
                          style: TextStyle(
                            fontSize: 24,
                            color: scheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _display,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _showTick ? 1 : 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: AppTheme.income),
                          const SizedBox(width: 4),
                          Text(
                            'Tap the tick to add $currency ${_fmt(_value)} '
                            'to your account',
                            style: TextStyle(
                              color: AppTheme.income,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // ---- keypad ----
            Expanded(
              flex: 5,
              child: Padding(
                // extra bottom room so the docked centre nav button never
                // sits over the last key row
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 34),
                child: Column(
                  children: [
                    _row([
                      _Key('C', kind: _KeyKind.function, onTap: _clear),
                      _Key.icon(Icons.backspace_outlined,
                          kind: _KeyKind.function, onTap: _backspace),
                      _Key('%', kind: _KeyKind.function, onTap: _percent),
                      _Key('÷', kind: _KeyKind.operator,
                          onTap: () => _tapOperator('÷')),
                    ]),
                    _row([
                      _Key('7', onTap: () => _tapDigit('7')),
                      _Key('8', onTap: () => _tapDigit('8')),
                      _Key('9', onTap: () => _tapDigit('9')),
                      _Key('×', kind: _KeyKind.operator,
                          onTap: () => _tapOperator('×')),
                    ]),
                    _row([
                      _Key('4', onTap: () => _tapDigit('4')),
                      _Key('5', onTap: () => _tapDigit('5')),
                      _Key('6', onTap: () => _tapDigit('6')),
                      _Key('−', kind: _KeyKind.operator,
                          onTap: () => _tapOperator('−')),
                    ]),
                    _row([
                      _Key('1', onTap: () => _tapDigit('1')),
                      _Key('2', onTap: () => _tapDigit('2')),
                      _Key('3', onTap: () => _tapDigit('3')),
                      _Key('+', kind: _KeyKind.operator,
                          onTap: () => _tapOperator('+')),
                    ]),
                    _row([
                      _Key('0', onTap: () => _tapDigit('0')),
                      _Key('.', onTap: () => _tapDigit('.')),
                      _Key('=', kind: _KeyKind.equals, onTap: _equals),
                      _Key.icon(
                        Icons.check,
                        kind: _KeyKind.tick,
                        onTap: _canAdd ? _addToAccount : null,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(List<Widget> keys) => Expanded(child: Row(children: keys));
}

enum _KeyKind { number, operator, equals, function, tick }

class _Key extends StatelessWidget {
  const _Key(
    this.label, {
    this.kind = _KeyKind.number,
    required this.onTap,
  }) : icon = null;

  const _Key.icon(
    this.icon, {
    this.kind = _KeyKind.number,
    required this.onTap,
  }) : label = null;

  final String? label;
  final IconData? icon;
  final _KeyKind kind;

  /// A null callback renders the key disabled (dimmed, non-tappable).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    switch (kind) {
      case _KeyKind.number:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
      case _KeyKind.operator:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
      case _KeyKind.equals:
        bg = scheme.primary;
        fg = scheme.onPrimary;
      case _KeyKind.tick:
        bg = AppTheme.income;
        fg = Colors.white;
      case _KeyKind.function:
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
    }

    final enabled = onTap != null;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: icon != null
                    ? Icon(icon,
                        color: fg, size: kind == _KeyKind.tick ? 30 : 24)
                    : Text(
                        label!,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
