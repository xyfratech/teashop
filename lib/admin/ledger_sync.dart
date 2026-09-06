import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../data/data_store.dart';

/// Cloud copy of the tea-shop ledger.
///
/// Every income / expense entry saved on-device is mirrored to the
/// `transactions` table in the app's Supabase project, keyed to the signed-in
/// shop owner's Firebase UID (stamped server-side). The owner — and the admin —
/// can read it back for off-device reporting.
///
/// Writes go through a Hive-backed outbox so nothing is lost when the device
/// is offline; the queue is drained on start-up, after every change and on a
/// slow retry timer. It only flushes while a shop owner is signed in.
class LedgerSync extends ChangeNotifier {
  LedgerSync(
    this._store, {
    required String? Function() shopId,
    required String Function() shopName,
    required bool Function() identityResolved,
  })  : _shopId = shopId,
        _shopName = shopName,
        _identityResolved = identityResolved;

  final DataStore _store;
  final String? Function() _shopId;
  final String Function() _shopName;
  // True once LicenseService has finished figuring out who is signed in
  // (admin vs. a specific shop). Every row must carry the *right* shop_id,
  // so flush() waits for this rather than risk sending rows with shop_id
  // still null right after sign-in — those would land un-scoped instead of
  // under the one store they belong to.
  final bool Function() _identityResolved;

  static const _table = 'transactions';
  static const _retryEvery = Duration(seconds: 90);

  Timer? _timer;
  bool _flushing = false;

  bool get enabled => true;

  /// The shared, Firebase-authenticated Supabase client.
  SupabaseClient get _client => Supabase.instance.client;
  bool get _signedIn => FirebaseAuth.instance.currentUser != null;

  /// Operations still waiting to reach the server.
  int get pending => _store.ledgerOutboxCount;
  bool get syncing => _flushing;
  DateTime? lastSyncAt;
  String? lastError;

  void start() {
    _timer = Timer.periodic(_retryEvery, (_) {
      if (pending > 0) unawaited(flush());
    });
    unawaited(flush());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- enqueue -------------------------------------------------------------

  /// [row] is the domain part of a transaction (see `AppState.ledgerRow`).
  /// `client_id` / `shop_id` / `updated_at` are stamped on at send time.
  Future<void> enqueueUpsert(Map<String, dynamic> row) async {
    if (!enabled) return;
    final queued = Map<String, dynamic>.from(row)..['_op'] = 'upsert';
    await _store.ledgerOutboxPut(queued['id'] as String, queued);
    notifyListeners();
    unawaited(flush());
  }

  Future<void> enqueueDelete(String id) async {
    if (!enabled) return;
    await _store.ledgerOutboxPut(id, {'_op': 'delete', 'id': id});
    notifyListeners();
    unawaited(flush());
  }

  Future<void> enqueueDeleteMany(Iterable<String> ids) async {
    if (!enabled) return;
    for (final id in ids) {
      await _store.ledgerOutboxPut(id, {'_op': 'delete', 'id': id});
    }
    notifyListeners();
    unawaited(flush());
  }

  /// One-time upload of everything already in the on-device ledger.
  Future<void> backfill(List<Map<String, dynamic>> rows) async {
    if (!enabled || _store.ledgerBackfillDone) return;
    for (final row in rows) {
      final queued = Map<String, dynamic>.from(row)..['_op'] = 'upsert';
      await _store.ledgerOutboxPut(queued['id'] as String, queued);
    }
    await _store.markLedgerBackfillDone();
    notifyListeners();
    unawaited(flush());
  }

  Future<void> syncNow() => flush();

  // --- drain -------------------------------------------------------------

  Future<void> flush() async {
    // RLS stamps the row's owner from the Firebase token, so there is nothing
    // to send until a shop owner is signed in. The queue simply waits.
    //
    // Also wait for LicenseService to finish resolving *which* shop this is
    // — right after sign-in _shopId() would otherwise still read null for a
    // moment, and a row pushed in that window would upsert with shop_id
    // unset instead of this store's id. Nothing is lost: the outbox just
    // holds the entry until identity is known, then the retry timer (or the
    // resolve-listener in main.dart) drains it with the correct shop_id.
    if (_flushing || !_signedIn || !_identityResolved()) return;
    final client = _client;
    _flushing = true;
    notifyListeners();

    final now = DateTime.now().toUtc().toIso8601String();
    final shopId = _shopId();
    final shopName = _shopName();
    var hitError = false;

    try {
      for (final entry in _store.ledgerOutbox()) {
        final row = Map<String, dynamic>.from(entry.value);
        final op = row.remove('_op');
        try {
          if (op == 'delete') {
            await client
                .from(_table)
                .update({'deleted': true, 'updated_at': now}).eq(
                    'id', row['id'] as String);
          } else {
            row['client_id'] = _store.clientId;
            if (shopId != null) row['shop_id'] = shopId;
            row['shop_name'] = shopName;
            row['updated_at'] = now;
            await client.from(_table).upsert(row, onConflict: 'id');
          }
          await _store.ledgerOutboxRemove(entry.key);
        } catch (e) {
          lastError = e.toString();
          hitError = true;
          break; // leave this and the rest queued for the next attempt
        }
      }
      if (!hitError) {
        lastError = null;
        lastSyncAt = DateTime.now();
      }
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }
}
