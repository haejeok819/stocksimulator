import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:stocksimulator/shared/services/firebase_runtime.dart';

Future<void> bootstrapFirebase() async {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
    FirebaseRuntime.isReady = false;
    return;
  }

  try {
    await Firebase.initializeApp();
    FirebaseRuntime.isReady = true;
  } catch (_) {
    FirebaseRuntime.isReady = false;
  }
}
