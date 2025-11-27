import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 보안 정보를 안전하게 저장하고 관리하는 서비스
/// Firebase Firestore에 사용자별로 저장하여 보안 강화
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // SharedPreferences 키 (로컬 캐시용)
  static const String _keyOpenAIApiKey = 'openai_api_key';
  static const String _keyFirebaseFunctionUrl = 'firebase_function_url';

  // Firestore 컬렉션 경로
  static const String _collectionUsers = 'users';
  static const String _fieldOpenAIApiKey = 'openaiApiKey';
  static const String _fieldFirebaseFunctionUrl = 'firebaseFunctionUrl';

  /// OpenAI API 키 저장 (Firestore + 로컬 캐시)
  Future<void> saveOpenAIApiKey(String apiKey) async {
    // 로컬 캐시에 저장 (오프라인 지원)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenAIApiKey, apiKey);

    // Firestore에 저장 (로그인된 사용자만)
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection(_collectionUsers)
            .doc(user.uid)
            .set({
          _fieldOpenAIApiKey: apiKey,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        // Firestore 저장 실패는 무시 (로컬 캐시는 저장됨)
        print('Firestore에 API 키 저장 실패: $e');
      }
    }
  }

  /// OpenAI API 키 불러오기 (Firestore 우선, 없으면 로컬 캐시, 마지막으로 기본값)
  Future<String?> getOpenAIApiKey() async {
    // 1. Firestore에서 가져오기 시도 (로그인된 사용자만)
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore
            .collection(_collectionUsers)
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final apiKey = doc.data()?[_fieldOpenAIApiKey] as String?;
          if (apiKey != null && apiKey.isNotEmpty) {
            // Firestore에서 가져온 값을 로컬 캐시에도 저장
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyOpenAIApiKey, apiKey);
            return apiKey;
          }
        }
      } catch (e) {
        // Firestore 읽기 실패 시 로컬 캐시로 폴백
        print('Firestore에서 API 키 불러오기 실패: $e');
      }
    }

    // 2. 로컬 캐시에서 가져오기
    final prefs = await SharedPreferences.getInstance();
    final localKey = prefs.getString(_keyOpenAIApiKey);
    if (localKey != null && localKey.isNotEmpty) {
      return localKey;
    }

    // 3. 기본값 반환
    if (defaultOpenAIApiKey.isNotEmpty) {
      return defaultOpenAIApiKey;
    }

    return null;
  }

  /// OpenAI API 키 삭제
  Future<void> deleteOpenAIApiKey() async {
    // 로컬 캐시 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOpenAIApiKey);

    // Firestore에서 삭제 (로그인된 사용자만)
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection(_collectionUsers)
            .doc(user.uid)
            .update({
          _fieldOpenAIApiKey: FieldValue.delete(),
        });
      } catch (e) {
        print('Firestore에서 API 키 삭제 실패: $e');
      }
    }
  }

  /// Firebase Function URL 저장 (Firestore + 로컬 캐시)
  Future<void> saveFirebaseFunctionUrl(String url) async {
    // 로컬 캐시에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirebaseFunctionUrl, url);

    // Firestore에 저장 (로그인된 사용자만)
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection(_collectionUsers)
            .doc(user.uid)
            .set({
          _fieldFirebaseFunctionUrl: url,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('Firestore에 Function URL 저장 실패: $e');
      }
    }
  }

  /// Firebase Function URL 불러오기
  Future<String?> getFirebaseFunctionUrl() async {
    // 1. Firestore에서 가져오기 시도
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore
            .collection(_collectionUsers)
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final url = doc.data()?[_fieldFirebaseFunctionUrl] as String?;
          if (url != null && url.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyFirebaseFunctionUrl, url);
            return url;
          }
        }
      } catch (e) {
        print('Firestore에서 Function URL 불러오기 실패: $e');
      }
    }

    // 2. 로컬 캐시에서 가져오기
    final prefs = await SharedPreferences.getInstance();
    final localUrl = prefs.getString(_keyFirebaseFunctionUrl);
    if (localUrl != null && localUrl.isNotEmpty) {
      return localUrl;
    }

    // 3. 기본값 반환
    return defaultFirebaseFunctionUrl;
  }

  /// 기본 OpenAI API 키 (Firestore에 없을 때 사용)
  /// 주의: 이 값은 Firestore에 저장하는 것을 권장합니다
  /// 보안을 위해 Git에 커밋하지 마세요. Firestore에 저장하거나 앱에서 입력하세요.
  static const String defaultOpenAIApiKey = ''; // Firestore에 저장하거나 앱에서 입력하세요

  /// 기본 Firebase Function URL
  static const String defaultFirebaseFunctionUrl = 
      'https://us-central1-ordoo-ded2e.cloudfunctions.net/createKakaoCustomToken';
}

