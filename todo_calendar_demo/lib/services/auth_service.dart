import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  // iOS에서 Google Sign In 설정 확인을 위해 서버 클라이언트 ID가 필요할 수 있음
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOS에서 필요할 수 있는 설정
    scopes: ['email', 'profile'],
  );

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 인증 상태 변화 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Google 로그인 시작');
      
      // Firebase 초기화 확인
      try {
        if (_auth.app == null) {
          print('Firebase가 초기화되지 않음');
          throw Exception('Firebase가 초기화되지 않았습니다.');
        }
        print('Firebase 초기화 확인됨');
      } catch (e) {
        print('Firebase 초기화 확인 중 오류: $e');
        rethrow;
      }
      
      // Google Sign In 플로우 시작
      print('Google Sign In 시작');
      GoogleSignInAccount? googleUser;
      
      // iOS에서 Google Sign In이 제대로 설정되었는지 확인
      try {
        // signIn() 호출을 안전하게 래핑
        print('Google Sign In signIn() 호출 전');
        
        // 직접 호출 (microtask로 감싸면 오히려 문제가 될 수 있음)
        googleUser = await _googleSignIn.signIn().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            print('Google Sign In 타임아웃');
            throw TimeoutException('Google 로그인 시간이 초과되었습니다.');
          },
        );
        
        print('Google Sign In 완료: ${googleUser != null}');
      } on PlatformException catch (e) {
        // iOS 플랫폼 예외 처리
        print('Google Sign In PlatformException: ${e.code} - ${e.message}');
        print('상세 정보: ${e.details}');
        
        if (e.code == 'sign_in_canceled' || e.message?.contains('cancel') == true) {
          print('사용자가 취소함');
          return null;
        }
        
        // 설정 오류인 경우
        if (e.code.contains('configuration') || 
            e.message?.contains('REVERSED_CLIENT_ID') == true ||
            e.message?.contains('URL scheme') == true ||
            e.code.contains('sign_in_failed')) {
          throw Exception('Google Sign In 설정 오류: ${e.message}\nInfo.plist에 REVERSED_CLIENT_ID를 URL Scheme으로 추가해야 합니다.');
        }
        
        rethrow;
      } catch (e, stackTrace) {
        print('Google Sign In 일반 오류: $e');
        print('스택 트레이스: $stackTrace');
        
        // 사용자가 취소한 경우
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('cancelled') || 
            errorString.contains('canceled') ||
            errorString.contains('sign_in_canceled')) {
          print('사용자가 취소함');
          return null;
        }
        
        // iOS에서 Google Sign In 설정이 안 되어 있을 수 있음
        if (errorString.contains('configuration') || 
            errorString.contains('reversed_client_id') ||
            errorString.contains('url scheme') ||
            errorString.contains('client_id') ||
            errorString.contains('sign_in_failed')) {
          throw Exception('Google Sign In이 제대로 설정되지 않았습니다.\nGoogleService-Info.plist에 REVERSED_CLIENT_ID가 있고, Info.plist의 URL Schemes에 추가되어야 합니다.');
        }
        
        rethrow;
      }
      
      if (googleUser == null) {
        // 사용자가 로그인 취소
        print('사용자가 Google 로그인 취소');
        return null;
      }

      // 인증 정보 가져오기
      print('Google 인증 정보 가져오기');
      GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication;
        print('Google 인증 정보 가져오기 완료');
      } catch (e) {
        print('Google 인증 정보 가져오기 오류: $e');
        rethrow;
      }

      // 토큰이 없는 경우 처리
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        print('Google 토큰이 없음');
        throw Exception('Google 인증 정보를 가져올 수 없습니다.');
      }

      // Firebase 인증 자격 증명 생성
      print('Firebase 자격 증명 생성');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      print('Firebase에 로그인 시도');
      try {
        final result = await _auth.signInWithCredential(credential);
        print('Firebase 로그인 성공');
        return result;
      } catch (firebaseError, stackTrace) {
        // Firebase 인증 실패 시 에러 전파
        print('Firebase 인증 오류: $firebaseError');
        print('스택 트레이스: $stackTrace');
        rethrow;
      }
    } catch (e, stackTrace) {
      // 사용자가 취소한 경우는 null 반환
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancelled') || 
          errorString.contains('canceled') ||
          errorString.contains('sign_in_canceled') ||
          errorString.contains('사용자가 취소')) {
        print('사용자가 취소함');
        return null;
      }
      print('Google 로그인 최종 오류: $e');
      print('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // Apple 로그인
  Future<UserCredential?> signInWithApple() async {
    try {
      // Firebase 초기화 확인
      if (_auth.app == null) {
        throw Exception('Firebase가 초기화되지 않았습니다.');
      }
      
      // Apple 로그인 요청
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // ID 토큰이 없는 경우 처리
      if (appleCredential.identityToken == null) {
        throw Exception('Apple 인증 정보를 가져올 수 없습니다.');
      }

      // OAuth 자격 증명 생성
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Firebase에 로그인
      final userCredential =
          await _auth.signInWithCredential(oauthCredential);

      // 이름 정보가 있으면 업데이트 (에러가 나도 로그인은 성공한 것으로 처리)
      try {
        if (appleCredential.givenName != null ||
            appleCredential.familyName != null) {
          await userCredential.user?.updateDisplayName(
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim(),
          );
        }
      } catch (nameError) {
        // 이름 업데이트 실패는 무시 (로그인은 성공)
        print('이름 업데이트 실패 (무시): $nameError');
      }

      return userCredential;
    } catch (e) {
      // 사용자가 취소한 경우는 null 반환
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancelled') || 
          errorString.contains('canceled') ||
          errorString.contains('user_cancel') ||
          errorString.contains('사용자가 취소') ||
          errorString.contains('authorization_error')) {
        return null;
      }
      print('Apple 로그인 오류: $e');
      rethrow;
    }
  }

  // 카카오톡 로그인
  Future<UserCredential?> signInWithKakao() async {
    try {
      // Firebase 초기화 확인
      if (_auth.app == null) {
        throw Exception('Firebase가 초기화되지 않았습니다.');
      }
      
      // 카카오톡 로그인 시도
      kakao.OAuthToken token;
      try {
        // 카카오톡 앱으로 로그인 시도
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        // 사용자가 취소한 경우 확인
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('cancelled') || 
            errorString.contains('canceled') ||
            errorString.contains('사용자가 취소') ||
            errorString.contains('user_cancel')) {
          return null;
        }
        // 카카오톡 앱이 없거나 실패하면 웹뷰로 로그인
        try {
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        } catch (webError) {
          // 웹뷰에서도 취소한 경우
          final webErrorString = webError.toString().toLowerCase();
          if (webErrorString.contains('cancelled') || 
              webErrorString.contains('canceled') ||
              webErrorString.contains('사용자가 취소') ||
              webErrorString.contains('user_cancel')) {
            return null;
          }
          rethrow;
        }
      }

      // 사용자 정보 가져오기
      final kakaoUser = await kakao.UserApi.instance.me();
      
      if (kakaoUser.id == null) {
        throw Exception('카카오 로그인 정보를 가져올 수 없습니다.');
      }

      // Firebase Custom Token을 서버에서 받아오기
      final customToken = await _getCustomTokenFromServer(
        kakaoUserId: kakaoUser.id.toString(),
        kakaoAccessToken: token.accessToken,
        kakaoEmail: kakaoUser.kakaoAccount?.email,
        kakaoNickname: kakaoUser.kakaoAccount?.profile?.nickname,
      );

      // Custom Token으로 Firebase에 로그인
      return await _auth.signInWithCustomToken(customToken);
    } catch (e) {
      // 사용자가 취소한 경우는 null 반환 (에러로 처리하지 않음)
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancelled') || 
          errorString.contains('canceled') ||
          errorString.contains('사용자가 취소') ||
          errorString.contains('user_cancel')) {
        return null;
      }
      print('카카오톡 로그인 오류: $e');
      rethrow;
    }
  }

  // 서버에서 Custom Token 받아오기
  Future<String> _getCustomTokenFromServer({
    required String kakaoUserId,
    required String kakaoAccessToken,
    String? kakaoEmail,
    String? kakaoNickname,
  }) async {
    // Firebase Functions URL
    const functionUrl = 'https://us-central1-ordoo-ded2e.cloudfunctions.net/createKakaoCustomToken';
    
    if (functionUrl == 'YOUR_FIREBASE_FUNCTIONS_URL_HERE') {
      throw Exception(
        'Firebase Functions URL이 설정되지 않았습니다.\n'
        'Firebase Functions를 설정하고 URL을 auth_service.dart에 추가하세요.'
      );
    }

    try {
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kakaoUserId': kakaoUserId,
          'kakaoAccessToken': kakaoAccessToken,
          'kakaoEmail': kakaoEmail,
          'kakaoNickname': kakaoNickname,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['customToken'] as String;
      } else {
        throw Exception('Custom Token 생성 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('서버에서 Custom Token을 받아오는 중 오류 발생: $e');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      // Google 로그인 상태면 Google도 로그아웃
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // 카카오톡 로그아웃
      try {
        await kakao.UserApi.instance.unlink();
      } catch (e) {
        // 카카오톡 로그인이 아닌 경우 무시
      }

      // Firebase 로그아웃
      await _auth.signOut();
    } catch (e) {
      print('로그아웃 오류: $e');
      rethrow;
    }
  }

  // 사용자 정보 가져오기
  String? get displayName => currentUser?.displayName;
  String? get email => currentUser?.email;
  String? get photoURL => currentUser?.photoURL;
  String? get uid => currentUser?.uid;
}

