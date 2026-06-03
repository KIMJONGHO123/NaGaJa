import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  // 현재 로그인된 사용자 (없으면 null)
  static User? get currentUser => _auth.currentUser;

  // 로그인 상태 변화 스트림 — main.dart에서 라우팅 분기에 사용
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google 로그인
  static Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // 사용자가 취소한 경우

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  // 로그아웃
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
