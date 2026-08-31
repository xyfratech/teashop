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

  testWidgets('renders rates, counts up and saves an income entry',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SafeArea(child: ChaiSnackCounter())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rates visible.
    expect(find.text('Chai'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('Add to account'), findsNothing); // button carries amount

    // Two chai + one snack.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();

    final total = 2 * state.chaiRate + 1 * state.snackRate;
    expect(total, greaterThan(0));

    // Save.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(state.totalIncome, total);
    final entry = state.txns.firstWhere((t) => t.type == TxnType.income);
    expect(state.categoryName(entry.categoryId), 'Tea Sales');
    expect(entry.note, '2 chai · 1 snack');
  });
}
