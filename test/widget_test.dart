import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teashop_manager/models/app_enums.dart';
import 'package:teashop_manager/models/category.dart';
import 'package:teashop_manager/models/product.dart';
import 'package:teashop_manager/models/txn.dart';

void main() {
  test('Product margin maths', () {
    final p = Product(id: '1', name: 'Tea', price: 10, cost: 4);
    expect(p.margin, 6);
    expect(p.marginPct, 60);
  });

  test('Txn round-trips through a map', () {
    final txn = Txn(
      id: 'x',
      type: TxnType.expense,
      amount: 12.5,
      categoryId: 'c1',
      date: DateTime(2026, 8, 29, 10, 30),
      note: 'Milk',
      method: PayMethod.upi,
    );
    final restored = Txn.fromMap(txn.toMap());
    expect(restored.amount, 12.5);
    expect(restored.type, TxnType.expense);
    expect(restored.method, PayMethod.upi);
    expect(restored.note, 'Milk');
    expect(restored.date, DateTime(2026, 8, 29, 10, 30));
  });

  test('Category parses an unknown type as expense', () {
    final c = Category.fromMap({'id': 'a', 'name': 'Misc', 'type': 'bogus'});
    expect(c.type, TxnType.expense);
  });

  testWidgets('Enums expose readable labels', (tester) async {
    expect(TxnType.income.label, 'Income');
    expect(PayMethod.upi.label, 'UPI');
    // Touch the framework so the binding initialises cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
