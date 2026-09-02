import 'dart:convert';

import 'package:http/http.dart' as http;

/// Turns a name typed in English / "Manglish" (Malayalam sounded out in Latin
/// letters, e.g. `masala chaya`) into Malayalam script (`മസാല ചായ`).
///
/// Uses Google's public Input Tools transliteration endpoint. Returns `null` on
/// any failure — no network, a timeout, or no candidate — so callers can just
/// leave the Malayalam field untouched.
Future<String?> transliterateToMalayalam(String input) async {
  final text = input.trim();
  if (text.isEmpty) return null;

  final uri = Uri.https('inputtools.google.com', '/request', {
    'text': text,
    'itc': 'ml-t-i0-und', // Latin -> Malayalam
    'num': '1', // best candidate only
    'cp': '0',
    'cs': '1',
    'ie': 'utf-8',
    'oe': 'utf-8',
  });

  try {
    final res =
        await http.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;

    // Shape: ["SUCCESS",[["masala chaya",["മസാല ചായ"],[],{...}]]]
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! List || body.length < 2 || body[0] != 'SUCCESS') return null;

    final results = body[1];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is! List || first.length < 2) return null;
    final candidates = first[1];
    if (candidates is! List || candidates.isEmpty) return null;

    final best = candidates.first;
    return (best is String && best.trim().isNotEmpty) ? best : null;
  } catch (_) {
    return null;
  }
}
