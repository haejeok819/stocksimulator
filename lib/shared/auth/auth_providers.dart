import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/auth/auth_controller.dart';
import 'package:stocksimulator/shared/auth/auth_repository.dart';
import 'package:stocksimulator/shared/auth/auth_repository_mock.dart';
import 'package:stocksimulator/shared/auth/auth_state.dart';

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepositoryMock();
});

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((Ref ref) {
  final AuthRepository repository = ref.watch(authRepositoryProvider);
  return AuthController(repository: repository);
});
