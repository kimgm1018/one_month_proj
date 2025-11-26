# 🔧 Firebase Google Sign-In CONFIGURATION_NOT_FOUND 오류 해결

## 문제
```
[firebase_auth/unknown] An internal error has occurred. [ CONFIGURATION_NOT_FOUND
```

이 오류는 Firebase Console에서 Google Sign-In 제공업체가 제대로 설정되지 않았을 때 발생합니다.

## 해결 방법

### 1단계: Firebase Console에서 Google Sign-In 활성화

1. **Firebase Console 접속**
   - https://console.firebase.google.com
   - 프로젝트: `ordoo-ded2e` 선택

2. **Authentication 설정**
   - 좌측 메뉴: **Authentication** 클릭
   - **Sign-in method** 탭 클릭

3. **Google 제공업체 활성화**
   - **Google** 제공업체 찾기
   - 클릭하여 설정 열기
   - **사용 설정** 토글을 **켜기**
   - **프로젝트 지원 이메일** 선택
   - **저장** 클릭

### 2단계: Web 클라이언트 ID 확인 및 설정

Google Sign-In이 작동하려면 **Web 클라이언트 ID**가 필요합니다.

1. **Google Cloud Console 접속**
   - https://console.cloud.google.com
   - 프로젝트: `ordoo-ded2e` 선택

2. **OAuth 클라이언트 ID 확인**
   - APIs 및 서비스 > 자격증명
   - **Web 애플리케이션** 타입의 OAuth 클라이언트 ID 확인
   - 없으면 생성:
     - + 자격증명 만들기 > OAuth 클라이언트 ID
     - 애플리케이션 유형: **웹 애플리케이션**
     - 이름: `Todo Calendar Demo Web`
     - 승인된 리디렉션 URI: `https://ordoo-ded2e.firebaseapp.com/__/auth/handler`
     - 만들기 클릭

3. **Firebase Console에 Web 클라이언트 ID 설정**
   - Firebase Console > Authentication > Sign-in method
   - Google 제공업체 설정 열기
   - **웹 SDK 구성** 섹션에서:
     - **웹 클라이언트 ID** 필드에 위에서 확인한 Web 클라이언트 ID 입력
     - **저장** 클릭

### 3단계: 앱 재빌드 및 테스트

```bash
flutter clean
flutter pub get
flutter run -d emulator-5554
```

## 확인 사항

### ✅ 체크리스트

- [ ] Firebase Console > Authentication > Sign-in method에서 Google이 **사용 설정**되어 있음
- [ ] Google Cloud Console에 **Web 애플리케이션** 타입의 OAuth 클라이언트 ID가 있음
- [ ] Firebase Console > Authentication > Sign-in method > Google 설정에 **웹 클라이언트 ID**가 입력되어 있음
- [ ] 앱 재빌드 완료
- [ ] Google 로그인 테스트 성공

## 참고

- Android에서는 `google-services.json`의 `oauth_client`가 자동으로 사용됩니다
- 하지만 Firebase Auth가 작동하려면 Web 클라이언트 ID도 필요합니다
- Web 클라이언트 ID는 Firebase Console의 Authentication 설정에서 입력해야 합니다

