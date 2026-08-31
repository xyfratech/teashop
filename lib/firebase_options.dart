// Firebase config for project `tea-shop-798ea`.
//
// Built by hand from android/app/google-services.json. Only an *Android* app is
// registered in the Firebase project, so web / desktop reuse the same project
// credentials (apiKey + projectId are project-scoped, which is enough for
// email/password auth and Firestore). If you add Google / OAuth sign-in on the
// web, register a proper Web app in the Firebase console (Project settings ->
// Add app -> Web) and paste its config here, or run
// `flutterfire configure --project=tea-shop-798ea`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        // iOS / macOS / Windows / Linux — reuse the project credentials.
        return web;
    }
  }

  static const String _apiKey = 'AIzaSyA1bc2CyDsa6V9vNH8jkpAJoJk4mUj0qhM';
  static const String _appId = '1:1049759207813:android:8d62471262c538a947b4ec';
  static const String _messagingSenderId = '1049759207813';
  static const String _projectId = 'tea-shop-798ea';
  static const String _storageBucket = 'tea-shop-798ea.firebasestorage.app';
  static const String _databaseURL =
      'https://tea-shop-798ea-default-rtdb.asia-southeast1.firebasedatabase.app';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    databaseURL: _databaseURL,
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: 'tea-shop-798ea.firebaseapp.com',
    storageBucket: _storageBucket,
    databaseURL: _databaseURL,
  );
}
