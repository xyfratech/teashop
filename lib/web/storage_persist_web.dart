import 'dart:js_interop';

/// `navigator.storage.persist()` — asks the browser to opt this origin out of
/// its best-effort eviction of site data under disk pressure. Support varies
/// by browser and the browser may still say no; either way the ledger stays
/// correct, this just lowers the odds of it being silently cleared.
@JS('navigator.storage.persist')
external JSPromise<JSBoolean> _persist();

Future<void> requestPersistentStorage() async {
  try {
    await _persist().toDart;
  } catch (_) {
    // Storage API (or navigator.storage.persist) unsupported — ignore.
  }
}
