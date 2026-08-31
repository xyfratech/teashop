import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../data/data_store.dart';
import 'shop.dart';
import 'supabase_config.dart';

const String kAppVersion = '1.0.0';

/// What the [LicenseGate] should show right now.
enum GateState {
  loading,
  shopAuth, // no session — show the login-id screen
  locked, // shop exists but expired or blocked
  ready, // shop active — run the app
  admin, // signed in as an admin — show the admin panel
  error, // could not resolve and have no cached answer
}

/// Owns identity and the shop's subscription record.
///
/// Everyone signs in with a single **login ID** (see [SupabaseConfig]). The id
/// is turned into a hidden Firebase email/password pair; the account is created
/// on first use. After sign-in [_resolve] decides who they are:
///  * [SupabaseConfig.adminLoginId] → admin panel
///  * an id the admin registered a shop for → that shop (linked on first login)
///  * anything else → an error asking them to contact the admin
class LicenseService extends ChangeNotifier with WidgetsBindingObserver {
  LicenseService(this._store);

  final DataStore _store;

  SupabaseClient get _sb => Supabase.instance.client;
  FirebaseAuth get _fb => FirebaseAuth.instance;

  StreamSubscription<User?>? _authSub;

  GateState _gate = GateState.loading;
  GateState get gate => _gate;

  Shop? _shop;
  Shop? get shop => _shop;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  String? _error;
  String? get error => _error;

  bool _busy = false;
  bool get busy => _busy;

  bool _offline = false;
  bool get offline => _offline;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _authSub = _fb.authStateChanges().listen((_) => unawaited(_resolve()));
    unawaited(_resolve());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _fb.currentUser != null) {
      _resolve();
    }
  }

  /// The login id the current Firebase account was created with.
  String? get _currentLoginId {
    final email = _fb.currentUser?.email;
    if (email == null || !email.contains('@')) return null;
    return email.split('@').first;
  }

  // ---------------------------------------------------------------------------
  // Resolution
  // ---------------------------------------------------------------------------

  Future<void> _resolve() async {
    if (_fb.currentUser == null) {
      _isAdmin = false;
      _shop = null;
      _set(GateState.shopAuth);
      return;
    }

    final loginId = _currentLoginId;

    // First call — this is our real "is the server reachable" probe.
    bool admin;
    try {
      admin = await _sb.rpc('is_admin') == true;
      _offline = false;
    } catch (e) {
      _fallBackToCache(e);
      return;
    }

    // From here a failure is a backend/setup problem, not connectivity — show
    // the actual message instead of "could not reach the server".
    try {
      if (!admin && loginId != null && SupabaseConfig.isAdminId(loginId)) {
        await _sb.rpc('claim_first_admin');
        admin = await _sb.rpc('is_admin') == true;
      }

      if (admin) {
        _isAdmin = true;
        _set(GateState.admin);
        return;
      }
      _isAdmin = false;

      Map? row;
      if (loginId != null) {
        try {
          row = await _sb.rpc('claim_shop_by_login',
              params: {'p_login_id': loginId}) as Map?;
        } on PostgrestException {
          row = null; // function missing / older schema
        }
      }
      row ??= await _sb.rpc('my_shop') as Map?;

      if (row == null || row.isEmpty) {
        _shop = null;
        _error = 'No shop is registered for "$loginId". '
            'Ask the admin to create your login.';
        _set(GateState.error);
        return;
      }
      _shop = Shop.fromJson(Map<String, dynamic>.from(row));
      await _store.setCachedShop(_shop!.toJson());
      _set(_shop!.active ? GateState.ready : GateState.locked);
      _heartbeat();
    } on PostgrestException catch (e) {
      _shop = null;
      _error = 'Backend error: ${e.message}';
      _set(GateState.error);
    } catch (e) {
      _shop = null;
      _error = e.toString().replaceFirst('Exception: ', '');
      _set(GateState.error);
    }
  }

  void _fallBackToCache([Object? _]) {
    final cached = _store.cachedShop();
    if (cached != null) {
      _shop = Shop.fromJson(cached);
      _offline = true;
      _set(_shop!.active ? GateState.ready : GateState.locked);
      return;
    }
    _offline = true;
    _error = 'Could not reach the server. Check your connection and retry.';
    _set(GateState.error);
  }

  void _set(GateState g) {
    _gate = g;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _error = _friendlyAuthError(e);
    } on PostgrestException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase — enable it';
      case 'network-request-failed':
        return 'No internet connection';
      case 'too-many-requests':
        return 'Too many attempts — try again later';
      case 'wrong-password':
      case 'invalid-credential':
        return 'That login ID is taken by a different app version';
      default:
        return e.message ?? 'Sign-in failed';
    }
  }

  // ---------------------------------------------------------------------------
  // Login (id only)
  // ---------------------------------------------------------------------------

  Future<void> signIn(String loginId) => _run(() async {
        final id = loginId.trim();
        if (id.isEmpty) throw Exception('Enter your login ID');
        final email = SupabaseConfig.loginEmail(id);
        final pw = SupabaseConfig.loginPassword(id);
        try {
          await _fb.signInWithEmailAndPassword(email: email, password: pw);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            await _fb.createUserWithEmailAndPassword(email: email, password: pw);
          } else {
            rethrow;
          }
        }
        await _resolve();
      });

  Future<void> updateShopName(String name) => _run(() async {
        if (_shop == null) return;
        await _sb.from('shops').update({'name': name.trim()}).eq('id', _shop!.id);
        await refresh();
      });

  Future<void> refresh() => _run(_resolve);

  Future<void> _heartbeat() async {
    try {
      final row = await _sb.rpc('shop_heartbeat', params: {
        'p_app_version': kAppVersion,
      });
      if (row != null && row is Map && row.isNotEmpty) {
        _shop = Shop.fromJson(Map<String, dynamic>.from(row));
        await _store.setCachedShop(_shop!.toJson());
        final next = _shop!.active ? GateState.ready : GateState.locked;
        if (next != _gate) _set(next);
      }
    } catch (_) {
      // best effort
    }
  }

  Future<void> signOut() => _run(() async {
        await _fb.signOut();
        await _store.clearCachedShop();
        _shop = null;
        _isAdmin = false;
        _set(GateState.shopAuth);
      });

  // ---------------------------------------------------------------------------
  // Admin
  // ---------------------------------------------------------------------------

  Future<List<Shop>> adminListShops() async {
    final rows = await _sb.rpc('admin_list_shops') as List;
    return rows
        .map((e) => Shop.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Creates a pending shop for a login id the admin picks. No Firebase account
  /// is made now — the shop links to whoever first signs in with that id.
  Future<Shop> adminRegisterShop({
    required String loginId,
    required String shopName,
    String? ownerName,
    int trialDays = SupabaseConfig.trialDays,
  }) async {
    try {
      final row = await _sb.rpc('admin_register_shop', params: {
        'p_login_id': loginId.trim(),
        'p_name': shopName.trim(),
        'p_owner_name':
            (ownerName ?? '').trim().isEmpty ? null : ownerName!.trim(),
        'p_trial_days': trialDays,
      });
      return Shop.fromJson(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Shop> adminExtend(String shopId, int months) async {
    final row = await _sb.rpc('admin_extend_shop', params: {
      'p_shop_id': shopId,
      'p_months': months,
    });
    return Shop.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<Shop> adminSetExpiry(String shopId, DateTime when) async {
    final row = await _sb.rpc('admin_set_expiry', params: {
      'p_shop_id': shopId,
      'p_expires_at': when.toUtc().toIso8601String(),
    });
    return Shop.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<Shop> adminSetBlocked(String shopId, bool blocked) async {
    final row = await _sb.rpc('admin_set_blocked', params: {
      'p_shop_id': shopId,
      'p_blocked': blocked,
    });
    return Shop.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<Shop> adminSetNote(String shopId, String note) async {
    final row = await _sb.rpc('admin_set_note', params: {
      'p_shop_id': shopId,
      'p_note': note,
    });
    return Shop.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> adminSignOut() => signOut();

  int get pricePerMonth => SupabaseConfig.pricePerMonth;
  String get currency => SupabaseConfig.currencySymbol;
}
