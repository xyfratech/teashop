import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:teashop_manager/data/data_store.dart';
import 'package:teashop_manager/models/app_enums.dart';
import 'package:teashop_manager/models/txn.dart';
import 'package:teashop_manager/state/app_state.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('teashop_test');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('first run seeds starter categories and products', () async {
    final store = DataStore();
    await store.init();
    final state = AppState(store);
    await state.load();

    expect(state.categoriesOfType(TxnType.income), isNotEmpty);
    expect(state.categoriesOfType(TxnType.expense), isNotEmpty);
    expect(state.products, isNotEmpty);
    expect(state.balance, 0);
  });

  test('income and expense entries move the balance and profit', () async {
    final store = DataStore();
    await store.init();
    final state = AppState(store);
    await state.load();
    await state.setOpeningBalance(500);

    final incomeCat = state.categoriesOfType(TxnType.income).first;
    final expenseCat = state.categoriesOfType(TxnType.expense).first;

    await state.addTxn(Txn(
      id: state.newId(),
      type: TxnType.income,
      amount: 200,
      categoryId: incomeCat.id,
      date: DateTime.now(),
    ));
    await state.addTxn(Txn(
      id: state.newId(),
      type: TxnType.expense,
      amount: 75,
      categoryId: expenseCat.id,
      date: DateTime.now(),
    ));

    expect(state.totalIncome, 200);
    expect(state.totalExpense, 75);
    expect(state.totalProfit, 125);
    expect(state.balance, 625); // 500 opening + 200 - 75
  });

  test('addQuickEntry files under a default category with no picker', () async {
    final store = DataStore();
    await store.init();
    final state = AppState(store);
    await state.load();

    await state.addQuickEntry(type: TxnType.income, amount: 1632, note: 'chai');
    await state.addQuickEntry(type: TxnType.expense, amount: 200);

    expect(state.totalIncome, 1632);
    expect(state.totalExpense, 200);
    expect(state.balance, 1432);

    final income = state.txns.firstWhere((t) => t.type == TxnType.income);
    expect(state.categoryName(income.categoryId), 'Other Income');
    expect(income.note, 'chai');

    final expense = state.txns.firstWhere((t) => t.type == TxnType.expense);
    expect(state.categoryName(expense.categoryId), 'Other Expense');
  });

  test('quick sale records an income txn for the product value', () async {
    final store = DataStore();
    await store.init();
    final state = AppState(store);
    await state.load();

    final product = state.products.first;
    await state.quickSale(product, qty: 3);

    expect(state.txns.length, 1);
    final txn = state.txns.first;
    expect(txn.type, TxnType.income);
    expect(txn.amount, product.price * 3);
    expect(txn.productId, product.id);
    expect(state.balance, product.price * 3);
  });

  test('data survives being reopened', () async {
    final store = DataStore();
    await store.init();
    final state = AppState(store);
    await state.load();
    await state.addTxn(Txn(
      id: state.newId(),
      type: TxnType.income,
      amount: 42,
      categoryId: state.categoriesOfType(TxnType.income).first.id,
      date: DateTime.now(),
    ));
    await Hive.close();

    final store2 = DataStore();
    await store2.init();
    final state2 = AppState(store2);
    await state2.load();
    expect(state2.totalIncome, 42);
  });
}
