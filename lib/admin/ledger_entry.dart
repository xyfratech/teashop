/// One income / expense entry as stored in the cloud `transactions` table.
///
/// This is the admin-side read model — the shop app itself works with
/// [Txn] locally. Only the columns the admin panel needs are pulled out.
class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.isIncome,
    required this.amount,
    required this.categoryName,
    required this.note,
    required this.method,
    required this.qty,
    required this.occurredAt,
    this.productName,
  });

  final String id;
  final bool isIncome;
  final double amount;
  final String categoryName;
  final String? productName;
  final String note;
  final String method;
  final int qty;
  final DateTime occurredAt;

  double get signedAmount => isIncome ? amount : -amount;

  factory LedgerEntry.fromRow(Map<String, dynamic> r) {
    final rawCat = (r['category_name'] as String?)?.trim();
    final occurred = r['occurred_at'] as String?;
    return LedgerEntry(
      id: r['id'] as String,
      isIncome: (r['type'] as String?) == 'income',
      amount: (r['amount'] as num?)?.toDouble() ?? 0,
      categoryName:
          rawCat != null && rawCat.isNotEmpty ? rawCat : 'Uncategorised',
      productName: (r['product_name'] as String?)?.trim().isNotEmpty == true
          ? (r['product_name'] as String).trim()
          : null,
      note: (r['note'] as String?) ?? '',
      method: (r['method'] as String?)?.trim().isNotEmpty == true
          ? (r['method'] as String).trim()
          : 'cash',
      qty: (r['qty'] as num?)?.toInt() ?? 1,
      occurredAt: occurred != null
          ? DateTime.parse(occurred).toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Income / expense roll-up for a shop's whole cloud ledger.
class ShopLedgerSummary {
  const ShopLedgerSummary({
    required this.income,
    required this.expense,
    required this.entryCount,
    this.firstEntryAt,
    this.lastEntryAt,
  });

  final double income;
  final double expense;
  final int entryCount;
  final DateTime? firstEntryAt;
  final DateTime? lastEntryAt;

  double get net => income - expense;

  factory ShopLedgerSummary.of(List<LedgerEntry> entries) {
    var income = 0.0, expense = 0.0;
    DateTime? first, last;
    for (final e in entries) {
      if (e.isIncome) {
        income += e.amount;
      } else {
        expense += e.amount;
      }
      if (first == null || e.occurredAt.isBefore(first)) first = e.occurredAt;
      if (last == null || e.occurredAt.isAfter(last)) last = e.occurredAt;
    }
    return ShopLedgerSummary(
      income: income,
      expense: expense,
      entryCount: entries.length,
      firstEntryAt: first,
      lastEntryAt: last,
    );
  }
}
