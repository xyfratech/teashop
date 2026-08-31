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

/// Which language menu-item names are shown in. English is always available;
/// Malayalam falls back to English for any item without a Malayalam name.
enum MenuLang {
  en,
  ml;

  String get label => this == MenuLang.en ? 'English' : 'മലയാളം';

  /// Short label for the compact toggle.
  String get chip => this == MenuLang.en ? 'EN' : 'മല';

  static MenuLang parse(String? s) => MenuLang.values.firstWhere(
        (e) => e.name == s,
        orElse: () => MenuLang.en,
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
