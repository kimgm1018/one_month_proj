# 🔐 인증 시스템 구현 로드맵

## 📋 개요
구글, 애플, 카카오톡 소셜 로그인 및 일반 로그인 기능을 추가하여 사용자별 데이터 관리 및 동기화를 구현합니다.

---

## 🎯 목표
1. 소셜 로그인 (구글, 애플, 카카오톡) 구현
2. 일반 이메일/비밀번호 로그인 구현
3. 사용자별 데이터 분리 및 관리
4. 로그인 상태 유지 (자동 로그인)
5. 보안 토큰 관리

---

## 🏗️ 아키텍처 선택

### 옵션 1: Firebase Authentication (권장) ⭐
**장점:**
- 빠른 구현 (구글, 애플, 이메일 로그인 내장)
- 보안 관리 자동화
- 무료 티어 제공
- 실시간 동기화 가능

**단점:**
- 카카오톡은 추가 설정 필요
- Firebase 의존성

### 옵션 2: 직접 백엔드 구축
**장점:**
- 완전한 제어권
- 커스터마이징 자유도 높음

**단점:**
- 개발 시간 증가
- 보안 구현 부담
- 서버 인프라 필요

**권장: 옵션 1 (Firebase) + 카카오톡 SDK 직접 연동**

---

## 📦 1단계: 프로젝트 설정 및 의존성 추가

### 1.1 Firebase 프로젝트 생성
- [ ] Firebase Console에서 프로젝트 생성
- [ ] Android 앱 등록 (SHA-1 키 등록 필요)
- [ ] iOS 앱 등록 (Bundle ID 설정)
- [ ] `google-services.json` (Android) 다운로드
- [ ] `GoogleService-Info.plist` (iOS) 다운로드

### 1.2 의존성 추가 (`pubspec.yaml`)
```yaml
dependencies:
  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  
  # 소셜 로그인
  google_sign_in: ^6.2.1
  sign_in_with_apple: ^6.1.1
  kakao_flutter_sdk: ^1.3.0  # 카카오톡
  
  # 상태 관리 (선택: Provider, Riverpod, Bloc 등)
  provider: ^6.1.2  # 또는 riverpod, bloc
  
  # 로컬 저장소 (토큰 저장용)
  shared_preferences: ^2.3.2
  
  # HTTP 클라이언트 (백엔드 연동 시)
  dio: ^5.7.0
```

### 1.3 Firebase 초기화
- [ ] `main.dart`에 Firebase 초기화 코드 추가
- [ ] Android/iOS 네이티브 설정 파일 추가

---

## 🔧 2단계: 인증 서비스 레이어 구현

### 2.1 인증 모델 생성
**파일:** `lib/models/user_model.dart`
```dart
class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final AuthProvider provider; // google, apple, kakao, email
  final DateTime? createdAt;
  
  // 로컬 데이터 동기화 상태
  final bool isDataSynced;
}
```

### 2.2 인증 서비스 구현
**파일:** `lib/services/auth_service.dart`

**기능:**
- [ ] 구글 로그인
- [ ] 애플 로그인
- [ ] 카카오톡 로그인
- [ ] 이메일/비밀번호 로그인
- [ ] 이메일/비밀번호 회원가입
- [ ] 로그아웃
- [ ] 토큰 갱신
- [ ] 현재 사용자 정보 가져오기

### 2.3 인증 상태 관리
**파일:** `lib/providers/auth_provider.dart` (또는 `lib/services/auth_state.dart`)

**기능:**
- [ ] 로그인 상태 감지 (Stream)
- [ ] 현재 사용자 정보 관리
- [ ] 자동 로그인 처리
- [ ] 로그인 상태 변경 알림

---

## 🎨 3단계: UI 구현

### 3.1 로그인 화면
**파일:** `lib/screens/login_screen.dart`

**구성 요소:**
- [ ] 앱 로고/브랜딩
- [ ] 구글 로그인 버튼
- [ ] 애플 로그인 버튼 (iOS만)
- [ ] 카카오톡 로그인 버튼
- [ ] 이메일/비밀번호 로그인 버튼
- [ ] 회원가입 링크
- [ ] 로딩 인디케이터

### 3.2 회원가입 화면
**파일:** `lib/screens/signup_screen.dart`

**구성 요소:**
- [ ] 이메일 입력 필드
- [ ] 비밀번호 입력 필드
- [ ] 비밀번호 확인 필드
- [ ] 이름 입력 필드 (선택)
- [ ] 회원가입 버튼
- [ ] 에러 메시지 표시

### 3.3 프로필 화면
**파일:** `lib/screens/profile_screen.dart`

**구성 요소:**
- [ ] 사용자 프로필 정보 표시
- [ ] 로그아웃 버튼
- [ ] 계정 삭제 옵션 (선택)

---

## 💾 4단계: 데이터 관리 전략

### 4.1 사용자별 데이터 분리

**현재 구조:**
- `TodoRepository` - 모든 할 일 관리
- `TodoThemeRepository` - 모든 테마 관리
- `RoadmapRepository` - 모든 로드맵 관리

**변경 필요:**
- [ ] 모든 Repository에 `userId` 파라미터 추가
- [ ] 데이터베이스 스키마에 `user_id` 컬럼 추가
- [ ] 쿼리 시 `WHERE user_id = ?` 조건 추가

### 4.2 데이터 동기화 전략

**옵션 A: 로컬 우선 (오프라인 지원)**
- 로컬 DB에 먼저 저장
- 백그라운드에서 서버와 동기화
- 충돌 해결 정책 필요

**옵션 B: 서버 우선**
- 서버에 먼저 저장 후 로컬에 캐시
- 오프라인 시 제한적 기능

**권장: 옵션 A (로컬 우선)**

### 4.3 데이터베이스 마이그레이션
- [ ] 기존 데이터 마이그레이션 계획 수립
- [ ] 사용자별 데이터 분리 스크립트 작성
- [ ] 마이그레이션 테스트

---

## 🔒 5단계: 보안 및 토큰 관리

### 5.1 토큰 저장
- [ ] `SharedPreferences` 또는 `flutter_secure_storage` 사용
- [ ] 리프레시 토큰 안전하게 저장
- [ ] 토큰 만료 시 자동 갱신

### 5.2 API 요청 보안
- [ ] 모든 API 요청에 인증 토큰 포함
- [ ] 토큰 만료 시 자동 재요청
- [ ] 네트워크 에러 처리

---

## 🌐 6단계: 백엔드 연동 (선택)

### 6.1 백엔드 API 설계
**필요한 엔드포인트:**
- `POST /auth/login` - 로그인
- `POST /auth/register` - 회원가입
- `GET /auth/user` - 사용자 정보
- `POST /sync/todos` - 할 일 동기화
- `POST /sync/themes` - 테마 동기화
- `POST /sync/roadmaps` - 로드맵 동기화

### 6.2 동기화 서비스 구현
**파일:** `lib/services/sync_service.dart`

**기능:**
- [ ] 로컬 → 서버 업로드
- [ ] 서버 → 로컬 다운로드
- [ ] 충돌 해결
- [ ] 동기화 상태 표시

---

## 🧪 7단계: 테스트 및 배포

### 7.1 테스트
- [ ] 각 소셜 로그인 플로우 테스트
- [ ] 로그아웃/재로그인 테스트
- [ ] 데이터 동기화 테스트
- [ ] 오프라인 모드 테스트
- [ ] 에러 케이스 테스트

### 7.2 배포 준비
- [ ] Android: SHA-1 키 등록 확인
- [ ] iOS: Bundle ID 및 URL Scheme 설정
- [ ] 카카오톡: 앱 키 및 리다이렉트 URI 설정
- [ ] 애플: Sign in with Apple 설정

---

## 📝 구현 순서 (우선순위)

### Phase 1: 기본 인증 (1-2주)
1. Firebase 설정 및 초기화
2. 구글 로그인 구현
3. 이메일/비밀번호 로그인 구현
4. 로그인 상태 관리
5. 기본 UI 구현

### Phase 2: 소셜 로그인 확장 (1주)
1. 애플 로그인 추가
2. 카카오톡 로그인 추가
3. 프로필 화면 구현

### Phase 3: 데이터 분리 (1-2주)
1. 데이터베이스 스키마 수정
2. Repository에 userId 추가
3. 기존 데이터 마이그레이션
4. 사용자별 데이터 필터링

### Phase 4: 동기화 (2-3주, 선택)
1. 백엔드 API 설계 및 구현
2. 동기화 서비스 구현
3. 충돌 해결 로직
4. 동기화 UI 표시

---

## 🔗 참고 자료

### Firebase
- [Firebase Auth 문서](https://firebase.google.com/docs/auth)
- [FlutterFire 문서](https://firebase.flutter.dev/)

### 소셜 로그인
- [Google Sign-In](https://pub.dev/packages/google_sign_in)
- [Sign in with Apple](https://pub.dev/packages/sign_in_with_apple)
- [Kakao Flutter SDK](https://pub.dev/packages/kakao_flutter_sdk)

### 보안
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [OAuth 2.0 가이드](https://oauth.net/2/)

---

## ❓ 결정 필요 사항

1. **백엔드 필요 여부**
   - Firebase만 사용할지?
   - 별도 백엔드 서버 구축할지?

2. **데이터 동기화 범위**
   - 모든 데이터를 동기화할지?
   - 특정 데이터만 동기화할지?

3. **오프라인 지원 범위**
   - 완전 오프라인 지원?
   - 제한적 오프라인 지원?

4. **기존 사용자 데이터 처리**
   - 기존 데이터를 어떻게 처리할지?
   - 마이그레이션 전략은?

---

## 📌 다음 단계

1. **Firebase 프로젝트 생성 및 설정**
2. **의존성 추가 및 초기 설정**
3. **구글 로그인부터 시작하여 단계적으로 구현**

원하시면 각 단계별로 상세한 코드 구현을 도와드릴 수 있습니다! 🚀



