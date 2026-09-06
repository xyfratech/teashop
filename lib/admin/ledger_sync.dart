import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../data/data_store.dart';

/// Cloud copy of the tea-shop ledger — two-way.
///
/// **Push:** every income / expense entry saved on-device is mirrored to the
/// `transactions` table in the app's Supabase project, keyed to the signed-in
/// shop owner's Firebase UID (stamped server-side).
///
/// **Pull:** [pull] reads that same set of rows back and merges them into the
/// on-device store. Because every device that signs in with the same login ID
/// authenticates as the same Firebase user, row-level security scopes the read
/// to exactly this shop's entries — so an entry added on one phone shows up on
/// every other device signed in with that ID.
///
/// Writes go through a Hive-backed outbox so nothing is lost when the device
/// is offline; the queue is drained on start-up, after every change and on a
/// slow retry timer. It only syncs while a shop owner is signed in.
class LedgerSync extends ChangeNotifier {
  LedgerSync(
    this._store, {
    required String? Function() shopId,
    required String Function() shopName,
    required bool Function() identityResolved,
    Future<int> Function(List<Map<String, dynamic>> rows)? applyRemote,
  })  : _shopId = shopId,
        _shopName = shopName,
        _identityResolved = identityResolved,
        _applyRemote = applyRemote;

  final DataStore _store;
  final String? Function() _shopId;
  final String Function() _shopName;

  /// Merges rows pulled from the server into the on-device ledger and returns
  /// how many local entries changed. Wired to `AppState.mergeRemoteLedger`.
  final Future<int> Function(List<Map<String, dynamic>> rows)? _applyRemote;
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
  bool _pulling = false;

  bool get enabled => true;

  /// A cloud pull is in progress (restoring entries from the server).
  bool get restoring => _pulling;

  /// When the ledger was last restored from the server.
  DateTime? lastPullAt;

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
      final since = lastPullAt;
      if (since == null ||
          DateTime.now().difference(since) > const Duration(minutes: 5)) {
        unawaited(pull());
      }
    });
    unawaited(syncNow());
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

  /// Upload anything pending, then restore the server's copy on top.
  Future<void> syncNow() async {
    await flush();
    await pull();
  }

  // --- pull / restore ----------------------------------------------------

  static const _pageSize = 1000; // PostgREST's default row cap

  /// Reads this shop's ledger back from the server and merges it into the
  /// on-device store. Safe to call often — it no-ops until a shop owner is
  /// signed in and their identity is resolved, and while another pull runs.
  ///
  /// The first pull of a session fetches the whole ledger (paged, so a large
  /// history is not truncated at [_pageSize]); later pulls only ask for rows
  /// touched since the last one, with a few minutes of overlap for clock skew.
  Future<void> pull() async {
    final apply = _applyRemote;
    if (apply == null || _pulling || !_signedIn || !_identityResolved()) {
      return;
    }
    _pulling = true;
    notifyListeners();
    try {
      // RLS restricts every read to rows whose user_id is the signed-in
      // Firebase UID — exactly the entries made under this login ID on any
      // device.
      final since = lastPullAt;
      final rows = <Map<String, dynamic>>[];
      for (var from = 0;; from += _pageSize) {
        var query = _client.from(_table).select();
        if (since != null) {
          query = query.gte(
            'updated_at',
            since
                .toUtc()
                .subtract(const Duration(minutes: 5))
                .toIso8601String(),
          );
        }
        final page = await query
            .order('updated_at', ascending: true)
            .range(from, from + _pageSize - 1) as List;
        rows.addAll(page.map((e) => Map<String, dynamic>.from(e as Map)));
        if (page.length < _pageSize) break;
      }
      await apply(rows);
      lastPullAt = DateTime.now();
      lastError = null;
    } catch (e) {
      lastError = e.toString();
    } finally {
      _pulling = false;
      notifyListeners();
    }
  }

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
