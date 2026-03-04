import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/auth/auth_controller.dart';
import 'package:stocksimulator/shared/auth/auth_repository.dart';
import 'package:stocksimulator/shared/auth/auth_repository_firebase_google.dart';
import 'package:stocksimulator/shared/auth/auth_repository_mock.dart';
import 'package:stocksimulator/shared/auth/auth_state.dart';
import 'package:stocksimulator/shared/services/firebase_runtime.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || !FirebaseRuntime.isReady) {
    return AuthRepositoryMock();
  }

  if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
    return AuthRepositoryFirebaseGoogle();
  }

  return AuthRepositoryMock();
});

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((Ref ref) {
  final AuthRepository repository = ref.watch(authRepositoryProvider);
  return AuthController(repository: repository);
});
