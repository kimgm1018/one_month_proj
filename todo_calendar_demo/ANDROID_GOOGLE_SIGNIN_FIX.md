# 🔧 Android Google Sign In 설정 가이드

## 문제 확인

안드로이드의 `google-services.json` 파일을 확인한 결과, `oauth_client` 배열이 비어있습니다:
```json
"oauth_client": []
```

이것이 안드로이드에서 Google Sign In이 작동하지 않는 원인입니다.

## 해결 방법

### 1단계: SHA-1 인증서 지문 확인

안드로이드에서 Google Sign In을 사용하려면 SHA-1 인증서 지문이 필요합니다.

#### 디버그 키스토어의 SHA-1 확인

**Windows (PowerShell):**
```powershell
cd android
.\gradlew signingReport
```

**또는 직접 키스토어 확인:**
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**macOS/Linux:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

출력에서 **SHA1:** 값 (예: `AA:BB:CC:DD:EE:FF:...`)을 복사하세요.

### 2단계: Firebase Console에서 SHA-1 등록

1. **Firebase Console 접속**
   - https://console.firebase.google.com 접속
   - 프로젝트: `ordoo-ded2e` 선택

2. **프로젝트 설정**
   - 좌측 톱니바퀴 아이콘 > **프로젝트 설정** 클릭

3. **앱 추가/수정**
   - **내 앱** 섹션에서 Android 앱 찾기
   - Android 앱이 없으면 **앱 추가** > **Android** 선택
   - 패키지 이름: `com.example.todo_calendar_demo` 입력

4. **SHA 인증서 지문 추가**
   - Android 앱 설정에서 **SHA 인증서 지문 추가** 클릭
   - 1단계에서 확인한 SHA-1 값 입력
   - **저장** 클릭

### 3단계: Google Cloud Console에서 Android OAuth 클라이언트 ID 생성

1. **Google Cloud Console 접속**
   - https://console.cloud.google.com 접속
   - 프로젝트: `ordoo-ded2e` 선택

2. **OAuth 클라이언트 ID 생성**
   - 좌측 메뉴: **APIs 및 서비스** > **자격증명**
   - **+ 자격증명 만들기** > **OAuth 클라이언트 ID** 선택

3. **Android 클라이언트 설정**
   - 애플리케이션 유형: **Android** 선택
   - 이름: `Todo Calendar Demo Android` (원하는 이름)
   - 패키지 이름: `com.example.todo_calendar_demo` 입력
   - SHA-1 인증서 지문: 1단계에서 확인한 SHA-1 값 입력
   - **만들기** 클릭

4. **클라이언트 ID 확인**
   - 생성된 클라이언트 ID 확인 (나중에 필요 없지만 확인용)

### 4단계: google-services.json 다시 다운로드

1. **Firebase Console**
   - 프로젝트 설정 > **내 앱** 섹션
   - Android 앱의 **google-services.json** 다운로드

2. **파일 교체**
   - 다운로드한 `google-services.json` 파일을 `android/app/google-services.json`에 덮어쓰기

3. **oauth_client 확인**
   - 새로 다운로드한 `google-services.json` 파일을 열어서 `oauth_client` 배열에 값이 있는지 확인
   - 다음과 같은 구조가 있어야 합니다:
   ```json
   "oauth_client": [
     {
       "client_id": "123456789-abc.apps.googleusercontent.com",
       "client_type": 1,
       "android_info": {
         "package_name": "com.example.todo_calendar_demo",
         "certificate_hash": "SHA1_HASH_HERE"
       }
     }
   ]
   ```

### 5단계: 앱 재빌드

```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

## 확인 사항

### ✅ 체크리스트

- [ ] SHA-1 인증서 지문 확인 완료
- [ ] Firebase Console에 SHA-1 등록 완료
- [ ] Google Cloud Console에서 Android OAuth 클라이언트 ID 생성 완료
- [ ] google-services.json 다시 다운로드 완료
- [ ] 새 google-services.json에 oauth_client가 포함되어 있는지 확인
- [ ] 앱 재빌드 및 테스트 완료

## 주의사항

1. **릴리즈 빌드용 SHA-1**
   - 릴리즈 빌드를 배포할 때는 릴리즈 키스토어의 SHA-1도 등록해야 합니다
   - 릴리즈 키스토어의 SHA-1 확인:
     ```bash
     keytool -list -v -keystore YOUR_RELEASE_KEYSTORE.jks -alias YOUR_ALIAS
     ```

2. **디버그 vs 릴리즈**
   - 디버그 빌드: `debug.keystore`의 SHA-1 사용
   - 릴리즈 빌드: 릴리즈 키스토어의 SHA-1 사용
   - 둘 다 Firebase Console에 등록해야 두 빌드 모두에서 작동합니다

## 문제 해결

### 여전히 작동하지 않는 경우

1. **google-services.json 확인**
   - `oauth_client` 배열이 비어있지 않은지 확인
   - `package_name`이 정확한지 확인

2. **SHA-1 확인**
   - Firebase Console에 등록한 SHA-1이 현재 사용 중인 키스토어의 SHA-1과 일치하는지 확인

3. **캐시 클리어**
   ```bash
   flutter clean
   cd android
   ./gradlew clean
   cd ..
   ```

## 참고 자료

- [Firebase Android 설정 가이드](https://firebase.google.com/docs/android/setup)
- [Google Sign-In Android 설정](https://developers.google.com/identity/sign-in/android/start-integrating)

