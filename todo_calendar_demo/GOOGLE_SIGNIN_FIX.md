# 🔧 Google Sign In iOS 설정 가이드

## 문제 상황
구글 로그인 시 앱이 크래시되는 문제는 `REVERSED_CLIENT_ID`가 없어서 발생합니다.

## 해결 방법

### 1단계: Google Cloud Console에서 OAuth 2.0 클라이언트 ID 생성

1. **Google Cloud Console 접속**
   - https://console.cloud.google.com 접속
   - Firebase 프로젝트 선택: `ordoo-ded2e`

2. **OAuth 2.0 클라이언트 ID 생성**
   - 좌측 메뉴: **APIs & Services** > **Credentials**
   - 상단 **+ CREATE CREDENTIALS** 클릭
   - **OAuth client ID** 선택

3. **iOS 클라이언트 설정**
   - Application type: **iOS** 선택
   - Name: `Todo Calendar Demo iOS` (원하는 이름)
   - Bundle ID: `com.example.todoCalendarDemo` (현재 Bundle ID와 일치해야 함)
   - **CREATE** 클릭

4. **클라이언트 ID 확인**
   - 생성된 클라이언트 ID 확인
   - 형식: `123456789-abc.apps.googleusercontent.com`

### 2단계: REVERSED_CLIENT_ID 계산

클라이언트 ID를 역순으로 변환합니다.

**변환 규칙:**
```
원본: 123456789-abc.apps.googleusercontent.com
변환: com.googleusercontent.apps.123456789-abc
```

**변환 방법:**
1. `.apps.googleusercontent.com` 부분을 제거
2. 앞에 `com.googleusercontent.apps.` 추가

**예시:**
- 클라이언트 ID: `520663563736-abc123def456.apps.googleusercontent.com`
- REVERSED_CLIENT_ID: `com.googleusercontent.apps.520663563736-abc123def456`

### 3단계: 파일 수정

#### 3-1. GoogleService-Info.plist 수정

파일 위치: `ios/Runner/GoogleService-Info.plist`

```xml
<key>REVERSED_CLIENT_ID</key>
<string>YOUR_REVERSED_CLIENT_ID_HERE</string>
```

위의 `YOUR_REVERSED_CLIENT_ID_HERE`를 2단계에서 계산한 값으로 변경하세요.

#### 3-2. Info.plist 수정

파일 위치: `ios/Runner/Info.plist`

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>YOUR_REVERSED_CLIENT_ID_HERE</string>
    <!-- 카카오톡 URL Scheme -->
    <string>kakaocaf071dcba072d4953e60518458fa707</string>
</array>
```

위의 `YOUR_REVERSED_CLIENT_ID_HERE`를 **GoogleService-Info.plist와 동일한 값**으로 변경하세요.

### 4단계: 앱 재빌드

1. **iOS 의존성 업데이트**
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. **앱 재빌드**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## 확인 사항

### ✅ 체크리스트

- [ ] Google Cloud Console에서 iOS OAuth 클라이언트 ID 생성 완료
- [ ] REVERSED_CLIENT_ID 계산 완료
- [ ] `GoogleService-Info.plist`에 REVERSED_CLIENT_ID 추가
- [ ] `Info.plist`의 URL Schemes에 REVERSED_CLIENT_ID 추가
- [ ] 두 파일의 REVERSED_CLIENT_ID 값이 동일한지 확인
- [ ] `pod install` 실행 완료
- [ ] 앱 재빌드 및 테스트 완료

## 주의사항

1. **Bundle ID 일치 확인**
   - Google Cloud Console의 Bundle ID와 Xcode 프로젝트의 Bundle ID가 정확히 일치해야 합니다.
   - 현재 Bundle ID: `com.example.todoCalendarDemo`

2. **REVERSED_CLIENT_ID 값 일치**
   - `GoogleService-Info.plist`와 `Info.plist`의 REVERSED_CLIENT_ID 값이 **반드시 동일**해야 합니다.

3. **Firebase Console vs Google Cloud Console**
   - Firebase Console에서 다운로드한 `GoogleService-Info.plist`에는 REVERSED_CLIENT_ID가 포함되지 않을 수 있습니다.
   - Google Cloud Console에서 OAuth 클라이언트 ID를 별도로 생성해야 합니다.

## 문제 해결

### 여전히 크래시가 발생하는 경우

1. **Xcode에서 직접 확인**
   - Xcode로 프로젝트 열기
   - Target > Info > URL Types 확인
   - REVERSED_CLIENT_ID가 URL Scheme으로 추가되어 있는지 확인

2. **로그 확인**
   - Xcode 콘솔에서 에러 메시지 확인
   - `REVERSED_CLIENT_ID` 또는 `URL scheme` 관련 에러 확인

3. **캐시 클리어**
   ```bash
   flutter clean
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter pub get
   ```

## 참고 자료

- [Google Sign-In iOS 설정 가이드](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Firebase iOS 설정 가이드](https://firebase.google.com/docs/ios/setup)


