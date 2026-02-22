import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:stocksimulator/shared/auth/auth_repository.dart';
import 'package:stocksimulator/shared/auth/auth_user.dart';
import 'package:stocksimulator/shared/services/user_store.dart';

class AuthRepositoryFirebaseGoogle implements AuthRepository {
  AuthRepositoryFirebaseGoogle({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    UserStore? userStore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _userStore = userStore ?? const UserStore();

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final UserStore _userStore;

  @override
  Future<AuthUser?> getCurrentUser() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('로그인이 취소되었습니다.');
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );

    final UserCredential userCredential =
        await _firebaseAuth.signInWithCredential(credential);
    final User? user = userCredential.user;
    if (user == null) {
      throw Exception('구글 로그인 사용자 정보를 불러오지 못했습니다.');
    }

    await _userStore.upsertGoogleUser(user);
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> signInWithKakao() {
    throw Exception('카카오 로그인은 준비 중입니다. 구글 로그인을 이용해주세요.');
  }

  @override
  Future<AuthUser> signInWithNaver() {
    throw Exception('네이버 로그인은 준비 중입니다. 구글 로그인을 이용해주세요.');
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }

  AuthUser _toAuthUser(User user) {
    return AuthUser(
      uid: user.uid,
      provider: 'google',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
