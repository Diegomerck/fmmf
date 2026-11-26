import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase platform configuration generated for `fmmf-finance`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Web right now. '
          'Run flutterfire configure to add native platform targets.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAnYcx9XFVO6y30lN7Q4T9-25KISSwwR2w',
    appId: '1:129207507523:web:253a099035a75fe5c5d2f6',
    messagingSenderId: '129207507523',
    projectId: 'fmmf-finance',
    authDomain: 'fmmf-finance.firebaseapp.com',
    storageBucket: 'fmmf-finance.firebasestorage.app',
  );
}

