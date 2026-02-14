// File generated with correct Firebase configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB_U6U87roMFqkNZPK4ueopuNw7lS9edFM',
    appId: '1:1040367289333:web:bb0bd07507ad72d24796bc',
    messagingSenderId: '1040367289333',
    projectId: 'neethiyaithedi-a2640',
    authDomain: 'neethiyaithedi-a2640.firebaseapp.com',
    databaseURL: 'https://neethiyaithedi-a2640-default-rtdb.firebaseio.com',
    storageBucket: 'neethiyaithedi-a2640.firebasestorage.app',
    measurementId: 'G-37FV9PTL0W',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCpXUSpgLlBUp0qhKqBotZjGoEGiA5Mceo',
    appId: '1:1040367289333:android:88620f4880350cf24796bc',
    messagingSenderId: '1040367289333',
    projectId: 'neethiyaithedi-a2640',
    storageBucket: 'neethiyaithedi-a2640.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB_U6U87roMFqkNZPK4ueopuNw7lS9edFM',
    appId: '1:1040367289333:ios:placeholder',
    messagingSenderId: '1040367289333',
    projectId: 'neethiyaithedi-a2640',
    storageBucket: 'neethiyaithedi-a2640.firebasestorage.app',
    iosBundleId: 'com.example.neethiyaithediApp',
  );
}
