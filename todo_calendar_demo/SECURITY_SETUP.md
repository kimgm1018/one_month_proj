# 🔐 보안 설정 가이드

## 완료된 보안 개선 사항

### 1. 보안 정보 저장 서비스 생성
- `lib/services/secure_storage_service.dart` 생성
- SharedPreferences를 사용하여 민감한 정보 안전하게 저장
- OpenAI API 키와 Firebase Function URL 저장/로드 기능

### 2. OpenAI API 키 자동 로드
- 앱 시작 시 저장된 API 키 자동 불러오기
- 기본값 설정 가능
- API 키 입력 시 자동 저장

### 3. 하드코딩된 정보 분리
- Firebase Function URL을 SecureStorageService에서 관리
- Firebase Web Options에 보안 주석 추가

## 기본 OpenAI API 키 설정

### 방법 1: 코드에서 직접 설정 (개발용)

`lib/services/secure_storage_service.dart` 파일을 열고:

```dart
static const String defaultOpenAIApiKey = 'sk-your-api-key-here'; // 여기에 기본 API 키 입력
```

### 방법 2: 앱에서 처음 한 번만 입력 (권장)

1. 앱 실행 후 로드맵 채팅 화면으로 이동
2. API 키 입력 버튼 클릭
3. API 키 입력 후 저장
4. 이후부터는 자동으로 불러와서 사용

## 보안 권장 사항

### ⚠️ 주의사항

1. **기본 API 키는 개발용으로만 사용**
   - 프로덕션에서는 기본값을 비워두고 사용자가 입력하도록 하는 것이 좋습니다
   - 또는 서버를 통해 API 키를 관리하는 것을 권장합니다

2. **Git에 커밋하지 않기**
   - API 키가 포함된 코드는 Git에 커밋하지 마세요
   - `.gitignore`에 관련 파일 추가 권장

3. **환경 변수 사용 (향후 개선)**
   - Flutter에서는 직접 지원하지 않지만, 빌드 시 주입하는 방법을 사용할 수 있습니다
   - 또는 서버를 통해 API 키를 제공하는 방법도 있습니다

## 현재 저장되는 정보

- ✅ OpenAI API 키: `SharedPreferences`에 암호화되지 않은 상태로 저장
  - 향후 `flutter_secure_storage`로 업그레이드 권장
- ✅ Firebase Function URL: `SharedPreferences`에 저장

## 향후 개선 사항

1. **flutter_secure_storage 사용**
   - 현재는 `SharedPreferences` 사용 (암호화 안 됨)
   - `flutter_secure_storage`로 업그레이드하면 더 안전합니다

2. **환경 변수 지원**
   - 빌드 시 환경 변수 주입
   - 또는 `.env` 파일 지원 (flutter_dotenv 패키지)

3. **서버를 통한 API 키 관리**
   - 사용자별 API 키를 서버에 저장
   - Firebase Firestore나 자체 백엔드 사용

