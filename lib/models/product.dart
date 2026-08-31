import 'app_enums.dart';

/// A menu item that can be sold with one tap (e.g. "Regular Tea").
class Product {
  Product({
    required this.id,
    required this.name,
    this.nameMl = '',
    required this.price,
    this.cost = 0,
    this.active = true,
  });

  final String id;
  String name;

  /// Optional Malayalam name. Blank means "no translation" — [displayName]
  /// then falls back to [name].
  String nameMl;

  /// Selling price per unit.
  double price;

  /// Cost to make one unit (used for margin insight).
  double cost;

  bool active;

  double get margin => price - cost;

  double get marginPct => price <= 0 ? 0 : (margin / price) * 100;

  /// The name to show for [lang] — English always, Malayalam only when set.
  String displayName(MenuLang lang) =>
      lang == MenuLang.ml && nameMl.trim().isNotEmpty ? nameMl.trim() : name;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'nameMl': nameMl,
        'price': price,
        'cost': cost,
        'active': active,
      };

  factory Product.fromMap(Map map) => Product(
        id: map['id'] as String,
        name: map['name'] as String,
        nameMl: (map['nameMl'] as String?) ?? '',
        price: (map['price'] as num).toDouble(),
        cost: (map['cost'] as num?)?.toDouble() ?? 0,
        active: (map['active'] as bool?) ?? true,
      );
}
