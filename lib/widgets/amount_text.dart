import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/formatters.dart';

/// Renders a money value with the shop currency, optionally with a +/- sign.
class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.signed = false,
    this.style,
    this.color,
  });

  final double value;
  final bool signed;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final currency = context.select<AppState, String>((s) => s.currency);
    final formatted = Money(currency).format(value.abs());
    final prefix = signed ? (value < 0 ? '− ' : '+ ') : '';
    return Text(
      '$prefix$formatted',
      style: (style ?? const TextStyle()).copyWith(color: color),
    );
  }
}
