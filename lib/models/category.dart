import 'app_enums.dart';

/// A spending / earning category (e.g. "Tea Sales", "Rent").
class Category {
  Category({
    required this.id,
    required this.name,
    required this.type,
    this.iconKey = 'other',
  });

  final String id;
  String name;
  TxnType type;
  String iconKey;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'iconKey': iconKey,
      };

  factory Category.fromMap(Map map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        type: TxnType.parse(map['type'] as String?),
        iconKey: (map['iconKey'] as String?) ?? 'other',
      );
}
