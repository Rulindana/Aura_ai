// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDvgJICpWwGo0rAN-asYGc9RpeK7inLznc',
    appId: '1:781788885501:web:b5e095a0f6d5ab3bb454394',
    messagingSenderId: '781788885501',
    projectId: 'aura-6894',
    authDomain: 'aura-6894.firebaseapp.com',
    storageBucket: 'aura-6894.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvgJICpWwGo0rAN-asYGc9RpeK7inLznc',
    appId: '1:781780885501:android:576c81f6e8f0d3ad454394', // You need to add this
    messagingSenderId: '781788885501',
    projectId: 'aura-6894',
    storageBucket: 'aura-6894.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDvgJICpWwGo0rAN-asYGc9RpeK7inLznc',
    appId: '1:781788885501:ios:YOUR_IOS_APP_ID', // You need to add this
    messagingSenderId: '781788885501',
    projectId: 'aura-6894',
    storageBucket: 'aura-6894.firebasestorage.app',
    iosBundleId: 'com.example.auraAi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDvgJICpWwGo0rAN-asYGc9RpeK7inLznc',
    appId: '1:781788885501:ios:YOUR_MACOS_APP_ID', // You need to add this
    messagingSenderId: '781788885501',
    projectId: 'aura-6894',
    storageBucket: 'aura-6894.firebasestorage.app',
    iosBundleId: 'com.example.auraAi',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDvgJICpWwGo0rAN-asYGc9RpeK7inLznc',
    appId: '1:781788885501:windows:YOUR_WINDOWS_APP_ID', // You need to add this
    messagingSenderId: '781788885501',
    projectId: 'aura-6894',
    storageBucket: 'aura-6894.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDvgJICpWwGo0rAN-asYGc9RpeK7inLznc',
    appId: '1:781788885501:linux:YOUR_LINUX_APP_ID', // You need to add this
    messagingSenderId: '781788885501',
    projectId: 'aura-6894',
    storageBucket: 'aura-6894.firebasestorage.app',
  );
}