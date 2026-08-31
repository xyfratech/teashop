import 'package:flutter/material.dart';

/// Named icons used by categories. Storing a key (not a code point) keeps
/// Flutter's icon tree-shaking happy.
const Map<String, IconData> kIconChoices = {
  'tea': Icons.emoji_food_beverage,
  'coffee': Icons.coffee,
  'snack': Icons.bakery_dining,
  'cash': Icons.payments,
  'milk': Icons.water_drop,
  'sugar': Icons.grain,
  'gas': Icons.local_fire_department,
  'rent': Icons.storefront,
  'salary': Icons.groups,
  'power': Icons.bolt,
  'water': Icons.opacity,
  'repair': Icons.build,
  'package': Icons.inventory_2,
  'transport': Icons.local_shipping,
  'phone': Icons.phone_iphone,
  'tax': Icons.receipt_long,
  'gift': Icons.card_giftcard,
  'bank': Icons.account_balance,
  'other': Icons.category,
};

IconData iconFor(String? key) => kIconChoices[key] ?? Icons.category;
