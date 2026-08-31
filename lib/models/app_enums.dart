// Core enums shared across the app.

enum TxnType {
  income,
  expense;

  String get label => this == TxnType.income ? 'Income' : 'Expense';

  static TxnType parse(String? s) => TxnType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => TxnType.expense,
      );
}

enum PayMethod {
  cash,
  upi,
  card,
  other;

  String get label {
    switch (this) {
      case PayMethod.cash:
        return 'Cash';
      case PayMethod.upi:
        return 'UPI';
      case PayMethod.card:
        return 'Card';
      case PayMethod.other:
        return 'Other';
    }
  }

  static PayMethod parse(String? s) => PayMethod.values.firstWhere(
        (e) => e.name == s,
        orElse: () => PayMethod.cash,
      );
}
