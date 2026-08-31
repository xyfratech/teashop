# Setup — Firebase Phone-OTP identity + Supabase data

Everyone (admin + shop owners) signs in with **phone number + SMS OTP**
(Firebase Phone Auth). Shop/subscription data lives in the Supabase project,
which trusts the Firebase ID token.

## 1. Firebase console (`tea-shop-798ea`)

1. **Authentication → Sign-in method → Phone → Enable.**
2. Still on the Phone provider → **Phone numbers for testing** → add:
   `+91 9400525063` → `123456`
   (the admin number — fixed code, no real SMS, no billing).
3. For real shop-owner numbers to skip reCAPTCHA on Android, add the app's
   **SHA-1 / SHA-256** (debug + release) under Project settings → Your apps →
   the Android app. Without it, real numbers still work but may show a
   reCAPTCHA. Test numbers never need it.

(Email/Password and Firestore from the earlier setup are no longer used —
`firebase/firestore.rules` is dead and can be ignored.)

## 2. Supabase project `uhnupswvhriprvtixdim` ("tea shop" / xyfratech)

1. **Authentication → Sign In / Providers → Third-Party Auth → Firebase**,
   project id `tea-shop-798ea` (already done).
2. SQL editor → run **`supabase/schema_firebase.sql`** (re-run — it's
   idempotent; adds phone columns, `admin_register_shop`, phone-based
   `claim_first_admin` / `my_shop`).
3. SQL editor → run **`supabase/ledger_schema.sql`** for the cloud ledger.

## 3. App

- `flutter pub get` (Firebase deps already resolved)
- Android needs `android.permission.INTERNET` — already in the manifest.
- **`flutter clean && flutter run`** on an Android device/emulator (phone OTP
  is Android-first; web needs a reCAPTCHA flow that isn't wired up).

## First run

| Who | How |
|-----|-----|
| **Admin** | Open app → enter **9400525063** → Send OTP → type **123456** → Verify. First time, it claims the sole admin row. |
| **Shop owner** | Admin: **Register shop** → owner's phone + shop name + free days. Owner opens the app, enters that phone, gets an OTP, verifies — the shop links to them automatically. |

## Change the admin number

Edit `SupabaseConfig.adminPhone` in `lib/admin/supabase_config.dart` **and** the
hard-coded `'+919400525063'` in `claim_first_admin()` inside
`supabase/schema_firebase.sql` (then re-run it).
