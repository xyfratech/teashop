/// Backend connection for the SaaS layer (shop registration + licensing +
/// the admin panel). The tea-shop's own ledger stays on-device; only the
/// subscription record lives here.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://uhnupswvhriprvtixdim.supabase.co';

  /// Publishable key — safe to ship in the client. All access is gated by
  /// row-level security and SECURITY DEFINER RPCs on the server.
  static const String publishableKey =
      'sb_publishable_s7TMmvcdEoLK5wdqSoSGUg_ExSrTjIN';

  /// Everyone signs in with a single **login ID** — no password, no OTP.
  /// Firebase Auth still needs an email + password, so both are derived from
  /// the id: `<id>@tsm.local` and a deterministic password built from the
  /// [_loginPepper]. The account is created on first use.
  ///
  /// The admin's id is preset here; typing it opens the admin panel.
  static const String adminLoginId = 'ADM1234';

  static const String _loginPepper = 'tsm-2026-Rk9mQ2xP7vLzWt4h';

  static String _norm(String id) => id.trim().toLowerCase();

  static String loginEmail(String id) => '${_norm(id)}@tsm.local';

  static String loginPassword(String id) => 'tsm.$_loginPepper.${_norm(id)}';

  static bool isAdminId(String id) => _norm(id) == _norm(adminLoginId);

  // ---------------------------------------------------------------------------
  // Ledger backup — pushes every income / expense entry to a `transactions`
  // table as a cloud copy (push-only; the app never reads it back). It now
  // lives in the SAME project as [url] above; kept as separate constants so
  // LedgerSync can use its own anonymous client. Run supabase/ledger_schema.sql
  // once so the table exists.
  // ---------------------------------------------------------------------------

  static const String ledgerUrl = 'https://uhnupswvhriprvtixdim.supabase.co';

  static const String ledgerPublishableKey =
      'sb_publishable_s7TMmvcdEoLK5wdqSoSGUg_ExSrTjIN';

  /// Master switch for the push-only ledger backup.
  static const bool ledgerBackupEnabled = true;

  /// Monthly price shown on the lock screen. Change here to reprice.
  static const int pricePerMonth = 49;
  static const String currencySymbol = '₹';

  /// Shown to shops when their subscription lapses. Put your real UPI id /
  /// WhatsApp number here.
  static const String supportUpiId = 'your-upi@bank';

  /// Customer-care WhatsApp number (shown in Settings and on the lock screen).
  static const String supportContact = '+91 73063 24011';

  /// Default free-trial length for a newly registered shop: 1 week.
  static const int trialDays = 7;
}
