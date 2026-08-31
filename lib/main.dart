import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/data_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final store = DataStore();
  await store.init();

  final appState = AppState(store);
  await appState.load();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const TeaShopApp(),
    ),
  );
}
