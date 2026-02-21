import 'package:stocksimulator/shared/auth/auth_user.dart';

class AuthState {
  const AuthState({
    required this.isLoading,
    this.user,
    this.errorMessage,
  });

  const AuthState.initial() : this(isLoading: true);

  final bool isLoading;
  final AuthUser? user;
  final String? errorMessage;

  bool get isSignedIn => user != null;

  AuthState copyWith({
    bool? isLoading,
    AuthUser? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
