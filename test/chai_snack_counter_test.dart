import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:teashop_manager/data/data_store.dart';
import 'package:teashop_manager/models/app_enums.dart';
import 'package:teashop_manager/state/app_state.dart';
import 'package:teashop_manager/theme/app_theme.dart';
import 'package:teashop_manager/widgets/chai_snack_counter.dart';

void main() {
  late Directory dir;
  late AppState state;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('teashop_test');
    Hive.init(dir.path);
    final store = DataStore();
    await store.init();
    state = AppState(store);
    await state.load();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: SafeArea(child: ChaiSnackCounter())),
          ),
        ),
      );

  testWidgets('lists menu items, tallies the bill and posts one entry per line',
      (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    // Seeded menu items, sorted by name, are on screen.
    expect(find.text('Black Tea'), findsOneWidget);
    expect(find.text('Special Tea'), findsOneWidget);

    final black = state.products.firstWhere((p) => p.name == 'Black Tea');
    final special = state.products.firstWhere((p) => p.name == 'Special Tea');

    // Two Black Tea (first row) + one Special Tea (last row).
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();

    final total = 2 * black.price + 1 * special.price;
    expect(find.text('2 items in this order'), findsNothing); // 3 items
    expect(find.text('3 items in this order'), findsOneWidget);

    // Post the order.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(state.totalIncome, total);

    final sales = state.txns.where((t) => t.type == TxnType.income).toList();
    expect(sales.length, 2);
    for (final t in sales) {
      expect(state.categoryName(t.categoryId), 'Tea Sales');
      expect(t.productId, isNotNull);
    }
    expect(sales.map((t) => t.note), containsAll(['Black Tea x2', 'Special Tea x1']));

    // Counts reset after posting.
    expect(find.text('Tap + to build an order'), findsOneWidget);
  });

  testWidgets('shows an empty state when the menu has no active items',
      (tester) async {
    for (final p in state.products) {
      await state.deleteProduct(p.id);
    }

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('No menu items yet'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
