import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/auth/auth_repository.dart';
import 'package:stocksimulator/shared/auth/auth_state.dart';
import 'package:stocksimulator/shared/auth/auth_user.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState.initial()) {
    _loadCurrentUser();
  }

  final AuthRepository _repository;

  Future<void> _loadCurrentUser() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final AuthUser? user = await _repository.getCurrentUser();
      state = state.copyWith(
        isLoading: false,
        user: user,
        clearUser: user == null,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        errorMessage: _toMessage(error, fallback: '로그인 상태를 불러오지 못했습니다.'),
      );
    }
  }

  Future<void> signInWithKakao() => _performSignIn(_repository.signInWithKakao);

  Future<void> signInWithGoogle() => _performSignIn(_repository.signInWithGoogle);

  Future<void> signInWithNaver() => _performSignIn(_repository.signInWithNaver);

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signOut();
      state = state.copyWith(isLoading: false, clearUser: true, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _toMessage(error, fallback: '로그아웃에 실패했습니다.'),
      );
    }
  }

  String _toMessage(Object error, {required String fallback}) {
    final String raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw.isEmpty ? fallback : raw;
  }

  Future<void> _performSignIn(Future<AuthUser> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final AuthUser user = await action();
      state = state.copyWith(isLoading: false, user: user, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _toMessage(error, fallback: '로그인에 실패했습니다.'),
      );
    }
  }
}
