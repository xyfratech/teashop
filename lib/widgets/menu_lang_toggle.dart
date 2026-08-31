import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../state/app_state.dart';

/// Compact `EN / മല` switch that flips [AppState.menuLang]. Used on the
/// Chai & snack counter and the Menu screen so item names show in the
/// chosen language everywhere at once.
class MenuLangToggle extends StatelessWidget {
  const MenuLangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppState, MenuLang>((s) => s.menuLang);
    return SegmentedButton<MenuLang>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        ),
      ),
      segments: [
        for (final l in MenuLang.values)
          ButtonSegment(value: l, label: Text(l.chip)),
      ],
      selected: {lang},
      onSelectionChanged: (s) =>
          context.read<AppState>().setMenuLang(s.first),
    );
  }
}
