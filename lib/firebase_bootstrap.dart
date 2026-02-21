import 'dart:io';

Future<void> bootstrapFirebase() async {
  // Windows desktop build must not link Firebase native plugins.
  if (Platform.isWindows) {
    return;
  }

  // Firebase initialization intentionally disabled here until
  // platform-specific Firebase plugin linkage is reintroduced safely.
}
