# Backend

- **Identity** (admin login + shop-owner logins) → Firebase Auth + a Firestore
  credential mirror. See [SETUP_FIREBASE.md](SETUP_FIREBASE.md).
- **Shop / subscription records** → this Supabase project
  (`crpqgcilalnvyxhbbzgc`), which trusts the Firebase ID token via third-party
  auth. Schema delta: [`migrations/20260830140000_firebase_auth.sql`](migrations/20260830140000_firebase_auth.sql).
- **Ledger backup** → a separate Supabase project, push-only
  ([`ledger_schema.sql`](ledger_schema.sql)).

Full step-by-step: **[SETUP_FIREBASE.md](SETUP_FIREBASE.md)**.
