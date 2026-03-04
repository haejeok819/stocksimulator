import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stocksimulator/shared/auth/auth_repository.dart';
import 'package:stocksimulator/shared/auth/auth_user.dart';

class AuthRepositoryMock implements AuthRepository {
  static const String _keyCurrentUser = 'auth_mock_current_user';

  AuthUser? _cachedUser;

  @override
  Future<AuthUser?> getCurrentUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_keyCurrentUser);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      _cachedUser = AuthUser.fromJson(json);
      return _cachedUser;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<AuthUser> signInWithKakao() => _signIn(provider: 'kakao', displayName: '카카오 사용자');

  @override
  Future<AuthUser> signInWithGoogle() => _signIn(provider: 'google', displayName: '구글 사용자');

  @override
  Future<AuthUser> signInWithNaver() => _signIn(provider: 'naver', displayName: '네이버 사용자');

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
  }

  Future<AuthUser> _signIn({required String provider, required String displayName}) async {
    final AuthUser user = AuthUser(
      uid: 'mock_${provider}_user',
      provider: provider,
      displayName: displayName,
    );
    _cachedUser = user;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    return user;
  }

}
