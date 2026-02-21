import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

Future<void> bootstrapFirebase() async {
  if (Platform.isWindows) {
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
