import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_enums.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/txn.dart';

/// Local, offline-first persistence built on Hive. Records are stored as plain
/// maps so no code generation / adapters are required.
class DataStore {
  static const _metaBoxName = 'meta';
  static const _categoryBoxName = 'categories';
  static const _productBoxName = 'products';
  static const _txnBoxName = 'txns';

  static const rupee = '₹';

  late Box _meta;
  late Box _categories;
  late Box _products;
  late Box _txns;

  final Uuid _uuid = const Uuid();
  String newId() => _uuid.v4();

  Future<void> init() async {
    _meta = await Hive.openBox(_metaBoxName);
    _categories = await Hive.openBox(_categoryBoxName);
    _products = await Hive.openBox(_productBoxName);
    _txns = await Hive.openBox(_txnBoxName);

    if (_meta.get('seeded') != true) {
      await _seed();
      await _meta.put('seeded', true);
    }
  }

  Future<void> _seed() async {
    final categories = <Category>[
      Category(id: newId(), name: 'Tea Sales', type: TxnType.income, iconKey: 'tea'),
      Category(id: newId(), name: 'Coffee Sales', type: TxnType.income, iconKey: 'coffee'),
      Category(id: newId(), name: 'Snacks & Food', type: TxnType.income, iconKey: 'snack'),
      Category(id: newId(), name: 'Other Income', type: TxnType.income, iconKey: 'cash'),
      Category(id: newId(), name: 'Milk & Tea Leaves', type: TxnType.expense, iconKey: 'milk'),
      Category(id: newId(), name: 'Sugar', type: TxnType.expense, iconKey: 'sugar'),
      Category(id: newId(), name: 'Gas / Fuel', type: TxnType.expense, iconKey: 'gas'),
      Category(id: newId(), name: 'Rent', type: TxnType.expense, iconKey: 'rent'),
      Category(id: newId(), name: 'Salaries', type: TxnType.expense, iconKey: 'salary'),
      Category(id: newId(), name: 'Electricity', type: TxnType.expense, iconKey: 'power'),
      Category(id: newId(), name: 'Water', type: TxnType.expense, iconKey: 'water'),
      Category(id: newId(), name: 'Maintenance', type: TxnType.expense, iconKey: 'repair'),
      Category(id: newId(), name: 'Packaging', type: TxnType.expense, iconKey: 'package'),
      Category(id: newId(), name: 'Other Expense', type: TxnType.expense, iconKey: 'other'),
    ];
    for (final c in categories) {
      await _categories.put(c.id, c.toMap());
    }

    final products = <Product>[
      Product(id: newId(), name: 'Regular Tea', price: 10, cost: 4),
      Product(id: newId(), name: 'Special Tea', price: 15, cost: 6),
      Product(id: newId(), name: 'Black Tea', price: 8, cost: 3),
      Product(id: newId(), name: 'Coffee', price: 20, cost: 8),
      Product(id: newId(), name: 'Green Tea', price: 25, cost: 10),
    ];
    for (final p in products) {
      await _products.put(p.id, p.toMap());
    }
  }

  // --- Settings (meta box) ---
  String get shopName => _meta.get('shopName', defaultValue: 'My Tea Shop') as String;
  Future<void> setShopName(String v) => _meta.put('shopName', v);

  String get currency => _meta.get('currency', defaultValue: rupee) as String;
  Future<void> setCurrency(String v) => _meta.put('currency', v);

  double get openingBalance =>
      (_meta.get('openingBalance', defaultValue: 0.0) as num).toDouble();
  Future<void> setOpeningBalance(double v) => _meta.put('openingBalance', v);

  String get themeMode => _meta.get('themeMode', defaultValue: 'system') as String;
  Future<void> setThemeMode(String v) => _meta.put('themeMode', v);

  // --- Categories ---
  List<Category> categories() => _categories.values
      .map((e) => Category.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<void> putCategory(Category c) => _categories.put(c.id, c.toMap());
  Future<void> deleteCategory(String id) => _categories.delete(id);

  // --- Products ---
  List<Product> products() => _products.values
      .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<void> putProduct(Product p) => _products.put(p.id, p.toMap());
  Future<void> deleteProduct(String id) => _products.delete(id);

  // --- Transactions ---
  List<Txn> txns() => _txns.values
      .map((e) => Txn.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<void> putTxn(Txn t) => _txns.put(t.id, t.toMap());
  Future<void> deleteTxn(String id) => _txns.delete(id);

  /// Wipes every record and re-seeds the starter data.
  Future<void> clearAll() async {
    await _txns.clear();
    await _products.clear();
    await _categories.clear();
    await _meta.clear();
    await _seed();
    await _meta.put('seeded', true);
  }
}
