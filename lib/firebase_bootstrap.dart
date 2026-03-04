import 'package:stocksimulator/shared/services/firebase_runtime.dart';

Future<void> bootstrapFirebase() async {
  await FirebaseRuntime.bootstrapFirebase();
}
