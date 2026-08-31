import 'package:flutter/material.dart';

import '../admin/ledger_sync.dart';
import '../data/data_store.dart';
import '../models/app_enums.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/txn.dart';

/// Income / expense totals for a period.
class PeriodSummary {
  const PeriodSummary(this.income, this.expense);

  final double income;
  final double expense;

  double get profit => income - expense;
}

/// The single source of truth for the UI. Loads everything into memory (a tea
/// shop's ledger is small) and exposes derived figures + CRUD.
class AppState extends ChangeNotifier {
  AppState(this._store);

  final DataStore _store;

  LedgerSync? _ledger;

  /// Wires the cloud-backup sink. Called once from `main` after both this
  /// state and [LedgerSync] exist.
  void attachLedgerSync(LedgerSync sync) => _ledger = sync;

  List<Category> _categories = [];
  List<Product> _products = [];
  List<Txn> _txns = [];

  List<Category> get categories => List.unmodifiable(_categories);
  List<Product> get products => List.unmodifiable(_products);
  List<Txn> get txns => List.unmodifiable(_txns);

  String newId() => _store.newId();

  // --- settings passthrough ---
  String get shopName => _store.shopName;
  String get currency => _store.currency;
  double get openingBalance => _store.openingBalance;

  double get chaiRate => _store.chaiRate;
  double get snackRate => _store.snackRate;

  ThemeMode get themeMode {
    switch (_store.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    _categories = _store.categories()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _products = _store.products()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _txns = _store.txns()..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  // --- derived figures ---
  double get totalIncome => _txns
      .where((t) => t.type == TxnType.income)
      .fold(0.0, (s, t) => s + t.amount);

  double get totalExpense => _txns
      .where((t) => t.type == TxnType.expense)
      .fold(0.0, (s, t) => s + t.amount);

  double get totalProfit => totalIncome - totalExpense;

  double get balance => openingBalance + totalIncome - totalExpense;

  List<Txn> txnsInMonth(DateTime month) => _txns
      .where((t) => t.date.year == month.year && t.date.month == month.month)
      .toList();

  PeriodSummary summaryForMonth(DateTime month) {
    var inc = 0.0, exp = 0.0;
    for (final t in txnsInMonth(month)) {
      if (t.type == TxnType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
      }
    }
    return PeriodSummary(inc, exp);
  }

  PeriodSummary summaryForDay(DateTime day) {
    var inc = 0.0, exp = 0.0;
    for (final t in _txns.where((t) =>
        t.date.year == day.year &&
        t.date.month == day.month &&
        t.date.day == day.day)) {
      if (t.type == TxnType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
      }
    }
    return PeriodSummary(inc, exp);
  }

  /// Category name -> total, for one month and one direction. Sorted desc.
  List<MapEntry<String, double>> categoryBreakdown(
    DateTime month,
    TxnType type,
  ) {
    final map = <String, double>{};
    for (final t in txnsInMonth(month).where((t) => t.type == type)) {
      final name = categoryName(t.categoryId);
      map[name] = (map[name] ?? 0) + t.amount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// The last [n] months, oldest first, each normalised to the 1st.
  List<DateTime> recentMonths(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) => DateTime(now.year, now.month - (n - 1 - i)));
  }

  Category? categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String categoryName(String id) => categoryById(id)?.name ?? 'Uncategorised';

  List<Category> categoriesOfType(TxnType type) =>
      _categories.where((c) => c.type == type).toList();

  Product? productById(String? id) {
    if (id == null) return null;
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  int categoryUsageCount(String id) =>
      _txns.where((t) => t.categoryId == id).length;

  // --- cloud backup ---
  /// The domain shape of a transaction as stored in the backup project's
  /// `transactions` table. Identity / ownership columns are added by
  /// [LedgerSync] when the row is sent.
  Map<String, dynamic> ledgerRow(Txn t) => {
        'id': t.id,
        'type': t.type.name,
        'amount': t.amount,
        'category_id': t.categoryId,
        'category_name': categoryName(t.categoryId),
        'product_id': t.productId,
        'product_name': productById(t.productId)?.name,
        'note': t.note,
        'qty': t.quantity,
        'method': t.method.name,
        'occurred_at': t.date.toUtc().toIso8601String(),
        'deleted': false,
      };

  List<Map<String, dynamic>> ledgerRows() => _txns.map(ledgerRow).toList();

  // --- mutations ---
  Future<void> addTxn(Txn t) async {
    await _store.putTxn(t);
    await _ledger?.enqueueUpsert(ledgerRow(t));
    await load();
  }

  Future<void> updateTxn(Txn t) async {
    await _store.putTxn(t);
    await _ledger?.enqueueUpsert(ledgerRow(t));
    await load();
  }

  Future<void> deleteTxn(String id) async {
    await _store.deleteTxn(id);
    await _ledger?.enqueueDelete(id);
    await load();
  }

  /// The category assigned to fast entries that skip the category picker.
  /// Prefers an "Other Income" / "Other Expense" bucket, else the first of
  /// that type, else anything.
  Category defaultCategoryFor(TxnType type) {
    final ofType = _categories.where((c) => c.type == type).toList();
    final preferred = type == TxnType.income ? 'other income' : 'other expense';
    return ofType.firstWhere(
      (c) => c.name.toLowerCase() == preferred,
      orElse: () => ofType.isNotEmpty ? ofType.first : _categories.first,
    );
  }

  /// The income category whose name contains [keyword] (case-insensitive),
  /// falling back to the default income bucket. Used by the Chai & snack
  /// counter to file a bill under "Tea Sales".
  Category incomeCategoryFor(String keyword) {
    final k = keyword.toLowerCase();
    return categoriesOfType(TxnType.income).firstWhere(
      (c) => c.name.toLowerCase().contains(k),
      orElse: () => defaultCategoryFor(TxnType.income),
    );
  }

  /// One-tap add used by the calculator tick, the dashboard buttons and the
  /// Entries screen. No category prompt — [defaultCategoryFor] is used unless
  /// an explicit [categoryId] is given.
  Future<void> addQuickEntry({
    required TxnType type,
    required double amount,
    String note = '',
    String? categoryId,
  }) async {
    final t = Txn(
      id: newId(),
      type: type,
      amount: amount,
      categoryId: categoryId ?? defaultCategoryFor(type).id,
      note: note,
      date: DateTime.now(),
    );
    await _store.putTxn(t);
    await _ledger?.enqueueUpsert(ledgerRow(t));
    await load();
  }

  /// Records a menu-item sale as an income transaction.
  Future<Txn> quickSale(
    Product p, {
    int qty = 1,
    PayMethod method = PayMethod.cash,
  }) async {
    final incomeCats = categoriesOfType(TxnType.income);
    final cat = incomeCats.firstWhere(
      (c) => c.name.toLowerCase().contains('tea'),
      orElse: () => incomeCats.isNotEmpty ? incomeCats.first : _categories.first,
    );
    final t = Txn(
      id: newId(),
      type: TxnType.income,
      amount: p.price * qty,
      categoryId: cat.id,
      note: '${p.name} x$qty',
      date: DateTime.now(),
      method: method,
      quantity: qty,
      productId: p.id,
    );
    await _store.putTxn(t);
    await _ledger?.enqueueUpsert(ledgerRow(t));
    await load();
    return t;
  }

  Future<void> addProduct(Product p) async {
    await _store.putProduct(p);
    await load();
  }

  Future<void> updateProduct(Product p) async {
    await _store.putProduct(p);
    await load();
  }

  Future<void> deleteProduct(String id) async {
    await _store.deleteProduct(id);
    await load();
  }

  Future<void> addCategory(Category c) async {
    await _store.putCategory(c);
    await load();
  }

  Future<void> updateCategory(Category c) async {
    await _store.putCategory(c);
    await load();
  }

  Future<void> deleteCategory(String id) async {
    await _store.deleteCategory(id);
    await load();
  }

  Future<void> setShopName(String v) async {
    await _store.setShopName(v);
    notifyListeners();
  }

  Future<void> setCurrency(String v) async {
    await _store.setCurrency(v);
    notifyListeners();
  }

  Future<void> setOpeningBalance(double v) async {
    await _store.setOpeningBalance(v);
    notifyListeners();
  }

  Future<void> setChaiRate(double v) async {
    await _store.setChaiRate(v);
    notifyListeners();
  }

  Future<void> setSnackRate(double v) async {
    await _store.setSnackRate(v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    await _store.setThemeMode(m.name);
    notifyListeners();
  }

  Future<void> clearAll() async {
    final wipedIds = _txns.map((t) => t.id).toList();
    await _store.clearAll();
    await _ledger?.enqueueDeleteMany(wipedIds);
    await load();
  }
}
