import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:stocksimulator/firebase_options.dart';

class FirebaseRuntime {
  FirebaseRuntime._();

  static bool isReady = false;
  static Object? initError;
  static Future<bool>? _initFuture;

  static Future<bool> bootstrapFirebase() {
    _initFuture ??= _bootstrapInternal();
    return _initFuture!;
  }

  static Future<bool> _bootstrapInternal() async {
    if (kIsWeb) {
      isReady = false;
      initError = null;
      return false;
    }

    if (Platform.isWindows) {
      isReady = false;
      initError = null;
      return false;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      isReady = false;
      initError = null;
      return false;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isReady = true;
      initError = null;
      if (kDebugMode) {
        debugPrint('[FirebaseRuntime] initializeApp success');
      }
      return true;
    } catch (error) {
      isReady = false;
      initError = error;
      if (kDebugMode) {
        debugPrint('[FirebaseRuntime] initializeApp failed: $error');
      }
      return false;
    }
  }
}
