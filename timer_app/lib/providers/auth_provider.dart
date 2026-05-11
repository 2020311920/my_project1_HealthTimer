import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  User? get user => _user;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkCurrentUser();
  }

  void _checkCurrentUser() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return false;
    }
  }

  Future<bool> signInWithKakao() async {
    try {
      kakao.OAuthToken token;
      
      // 1. 카카오 로그인 (앱 또는 웹뷰)
      if (await kakao.isKakaoTalkInstalled()) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          debugPrint('카카오톡으로 로그인 실패 $error');
          // 사용자가 카카오톡 설치 후 디바이스 권한 요청 화면에서 로그인을 취소한 경우,
          // 의도적인 취소로 보고 카카오계정으로 로그인 시도 없이 로그인 취소로 처리 (예: 뒤로 가기)
          if (error is PlatformException && error.code == 'CANCELED') {
            return false;
          }
          // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인 시도
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 2. 카카오 사용자 정보(OIDC ID 토큰 등) 확인
      // Firebase OIDC 설정과 매칭을 위해 카카오 ID 토큰(idToken)을 사용
      if (token.idToken != null) {
        // Firebase 'kakao' OIDC 제공업체로 인증
        final OAuthProvider provider = OAuthProvider('oidc.kakao');
        final OAuthCredential credential = provider.credential(
          idToken: token.idToken,
          accessToken: token.accessToken,
        );

        await _auth.signInWithCredential(credential);
        return true;
      } else {
        debugPrint("Kakao idToken is null. OIDC 로그인을 위해서는 idToken이 필요합니다.");
        return false;
      }
    } catch (e) {
      debugPrint("Kakao Sign-In Error: $e");
      return false;
    }
  }

  Future<void> refreshUser() async {
    await _auth.currentUser?.reload();
    _user = _auth.currentUser;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    // 카카오 로그아웃 (SDK 세션 만료)
    try {
      await kakao.UserApi.instance.logout();
    } catch (e) {
      debugPrint("Kakao logout error: $e");
    }
    await _auth.signOut();
  }
}
