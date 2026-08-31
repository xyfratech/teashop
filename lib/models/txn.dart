import 'app_enums.dart';

/// A single money movement — a sale (income) or a purchase / bill (expense).
class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note = '',
    this.method = PayMethod.cash,
    this.quantity = 1,
    this.productId,
  });

  final String id;
  TxnType type;
  double amount;
  String categoryId;
  String note;
  DateTime date;
  PayMethod method;
  int quantity;
  String? productId;

  double get signedAmount => type == TxnType.income ? amount : -amount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        'date': date.toIso8601String(),
        'method': method.name,
        'quantity': quantity,
        'productId': productId,
      };

  factory Txn.fromMap(Map map) => Txn(
        id: map['id'] as String,
        type: TxnType.parse(map['type'] as String?),
        amount: (map['amount'] as num).toDouble(),
        categoryId: map['categoryId'] as String,
        note: (map['note'] as String?) ?? '',
        date: DateTime.parse(map['date'] as String),
        method: PayMethod.parse(map['method'] as String?),
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        productId: map['productId'] as String?,
      );
}
