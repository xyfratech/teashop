import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'admin/ledger_sync.dart';
import 'admin/license_service.dart';
import 'admin/supabase_config.dart';
import 'data/data_store.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'web/storage_persist.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Best-effort on web: ask the browser not to evict this site's storage
  // under disk pressure, so the ledger in IndexedDB stays put. No-op on
  // native platforms.
  unawaited(requestPersistentStorage());

  try {
    // Firebase owns identity (admin + shop-owner logins).
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Supabase keeps the shop / subscription records. It has no auth users of
    // its own any more — every request carries the current Firebase ID token,
    // which Supabase is configured to trust (third-party auth).
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      accessToken: () async =>
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '',
    );
  } catch (e) {
    // Almost always: `flutterfire configure` has not been run yet, so
    // lib/firebase_options.dart is still the placeholder. Show why instead of
    // a blank screen.
    runApp(_StartupErrorApp(error: '$e'));
    return;
  }

  final store = DataStore();
  await store.init();

  final appState = AppState(store);
  await appState.load();

  final licenseService = LicenseService(store)..start();

  // Cloud backup of the ledger — pushes every entry to a separate Supabase
  // project. Never blocks start-up and stays inert if the backend is missing.
  final ledgerSync = LedgerSync(
    store,
    shopId: () => licenseService.shop?.id,
    shopName: () => licenseService.shop?.name ?? store.shopName,
    // GateState.loading means LicenseService hasn't yet learned whether this
    // sign-in is the admin or, if not, which shop it is — shopId() would
    // still read null. Once the gate moves past loading, shopId() (when
    // there is one) is final for this session.
    identityResolved: () => licenseService.gate != GateState.loading,
    // Pulls the shop's entries back from the server and merges them in, so a
    // ledger built up on one device shows up on every device using the same
    // login ID.
    applyRemote: appState.mergeRemoteLedger,
  )..start();
  appState.attachLedgerSync(ledgerSync);
  await ledgerSync.backfill(appState.ledgerRows());

  // Once the gate settles we know which shop is signed in. If it's a
  // *different* shop than the one this device's ledger was built for, wipe the
  // local ledger so the previous shop's entries don't show under this login —
  // the new shop's own entries are then restored from the cloud. Also kicks
  // the sync immediately instead of waiting on the 90s retry timer (the first
  // flush after a fresh sign-in otherwise races LicenseService's network
  // round-trip and sits out).
  var handlingIdentity = false;
  Future<void> onIdentitySettled() async {
    if (handlingIdentity || licenseService.gate == GateState.loading) return;
    handlingIdentity = true;
    try {
      final id = licenseService.currentLoginId;
      if (id != null && store.boundLoginId != id) {
        if (store.boundLoginId != null) {
          appState.clearInMemory();
          await store.resetForNewLogin();
          await appState.load();
        }
        await store.setBoundLoginId(id);
      }
      await ledgerSync.syncNow();
    } finally {
      handlingIdentity = false;
    }
  }

  licenseService.addListener(() => unawaited(onIdentitySettled()));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<LicenseService>.value(value: licenseService),
        ChangeNotifierProvider<LedgerSync>.value(value: ledgerSync),
      ],
      child: const TeaShopApp(),
    ),
  );
}

/// Shown when Firebase / Supabase could not be initialised at start-up.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Backend not configured',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Run this once, then rebuild:\n\n'
                    'dart pub global activate flutterfire_cli\n'
                    'flutterfire configure --project=tea-shop-798ea\n'
                    'flutter pub get\n\n'
                    'See supabase/SETUP_FIREBASE.md for the full checklist.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
