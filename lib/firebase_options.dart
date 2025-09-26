import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACxlc2PWN92qI9L015_xB_hSCj3ye9fa8',
    appId: '1:766645636867:android:4517659136d2a25e4fe336',
    messagingSenderId: '766645636867',
    projectId: 'app-warehouse-55797',
    storageBucket: 'app-warehouse-55797.firebasestorage.app',
  );

  // iOS configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyACxlc2PWN92qI9L015_xB_hSCj3ye9fa8',
    appId: '1:766645636867:ios:4517659136d2a25e4fe336',
    messagingSenderId: '766645636867',
    projectId: 'app-warehouse-55797',
    storageBucket: 'app-warehouse-55797.firebasestorage.app',
    iosBundleId: 'com.example.app_warehouse',
  );

  // Web configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyACxlc2PWN92qI9L015_xB_hSCj3ye9fa8',
    appId: '1:766645636867:web:4517659136d2a25e4fe336',
    messagingSenderId: '766645636867',
    projectId: 'app-warehouse-55797',
    storageBucket: 'app-warehouse-55797.appspot.com',
  );

  // Dummy configuration for desktop platforms
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );

  static const FirebaseOptions windows = linux;
  static const FirebaseOptions macos = linux;
}
