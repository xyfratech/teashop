/// No-op on native platforms (Android / iOS / Windows). Their local storage
/// isn't subject to the browser's best-effort eviction under disk pressure,
/// so there is nothing to request here.
Future<void> requestPersistentStorage() async {}
