import 'package:stocksimulator/shared/auth/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> getCurrentUser();
  Future<AuthUser> signInWithKakao();
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithNaver();
  Future<void> signOut();
}
