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
  })  : _shopId = shopId,
        _shopName = shopName;

  final DataStore _store;
  final String? Function() _shopId;
  final String Function() _shopName;

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
    if (_flushing || !_signedIn) return;
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
