import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBAQjDhDwVOM_hrfrqH8oHoz3BnZbq4EpA',
    appId: '1:539511023898:web:8c8c446df2abde36d7e4a3',
    messagingSenderId: '539511023898',
    projectId: 'finderr-x-bmsce',
    authDomain: 'finderr-x-bmsce.firebaseapp.com',
    storageBucket: 'finderr-x-bmsce.appspot.com',
    measurementId: 'G-MPRGD5BG4N',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6Lf7v2ap8YrwYx_Qlnlp-v3rup2l8ENo',
    appId: '1:539511023898:android:a272192a22750262d7e4a3',
    messagingSenderId: '539511023898',
    projectId: 'finderr-x-bmsce',
    storageBucket: 'finderr-x-bmsce.appspot.com',
  );
}
