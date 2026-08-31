import 'package:flutter/material.dart';

/// Distinct, readable colours for pie / bar segments.
const List<Color> kChartPalette = [
  Color(0xFF2E7D32),
  Color(0xFFEF6C00),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFF00838F),
  Color(0xFF558B2F),
  Color(0xFFAD1457),
  Color(0xFF4E342E),
  Color(0xFF37474F),
];

Color paletteColor(int i) => kChartPalette[i % kChartPalette.length];
