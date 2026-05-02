import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase options for web are not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase options for macOS are not configured.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Firebase options for windows are not configured.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase options for linux are not configured.',
        );
      default:
        throw UnsupportedError(
          'Firebase options are not supported on this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBdFg7cMX3c2FIYWkNHxoYf5k-gsAxbf1k',
    appId: '1:156597534193:android:5da7027d0ef2d7d50b9850',
    messagingSenderId: '156597534193',
    projectId: 'cartly-e36ee',
    storageBucket: 'cartly-e36ee.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBIhR0Hh6r4GvtF_uzeckemZjd4uYtmaB0',
    appId: '1:80624375983:ios:7240d33c5054ae7dbcdc5a',
    messagingSenderId: '80624375983',
    projectId: 'cartly-push',
    storageBucket: 'cartly-push.firebasestorage.app',
    iosBundleId: 'com.seungdae.cartly',
  );
}
