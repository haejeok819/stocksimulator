import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions are not configured for web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCXN-HhZy7JLjjLdKtd2E39EYLkkyD5SN0',
    appId: '1:242887280631:android:c04a35020026b7468590f2',
    messagingSenderId: '242887280631',
    projectId: 'stock-a0a8c',
    storageBucket: 'stock-a0a8c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGvukcjsm_mRwz-eZB-LiFYoH-MeSm2os',
    appId: '1:242887280631:ios:f4a3d58b9d0046488590f2',
    messagingSenderId: '242887280631',
    projectId: 'stock-a0a8c',
    storageBucket: 'stock-a0a8c.firebasestorage.app',
    androidClientId: '242887280631-hd5gft380uqehnok8qtlq0n53pehfqsl.apps.googleusercontent.com',
    iosClientId: '242887280631-71jbh5b7s483h6j9g44n1auson3coe8m.apps.googleusercontent.com',
    iosBundleId: 'com.motorstock.stocksimulator',
  );

}