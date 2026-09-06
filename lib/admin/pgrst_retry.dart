import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// PostgREST briefly rejects a fresh Firebase ID token with "JWT issued at
/// future" (code `PGRST303`) when the token's `iat` is a hair ahead of the
/// database server's clock — this is normal clock skew between Google's auth
/// servers and Supabase's, and it clears itself within a second or two. A
/// single short-delayed retry is enough; anything else is a real error and is
/// rethrown as-is.
Future<T> withClockSkewRetry<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on PostgrestException catch (e) {
    if (e.code != 'PGRST303') rethrow;
    await Future.delayed(const Duration(seconds: 2));
    return await action();
  }
}
