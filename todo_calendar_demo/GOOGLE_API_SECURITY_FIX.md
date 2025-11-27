# 🔒 Google API 보안 경고 해결 가이드

## 문제 상황
Google에서 API 키 보안 경고 메일이 왔습니다. 이는 API 키가 노출되었거나 제한이 설정되지 않았을 때 발생합니다.

## 해결 방법

### 1단계: Google Cloud Console에서 API 키 제한 설정

1. **Google Cloud Console 접속**
   - https://console.cloud.google.com
   - 프로젝트: `ordoo-ded2e` 선택

2. **API 키 목록 확인**
   - 좌측 메뉴: **APIs 및 서비스** > **사용자 인증 정보**
   - **API 키** 섹션에서 모든 API 키 확인

3. **각 API 키에 제한 설정**

   #### Android용 API 키 제한
   - API 키 클릭하여 편집
   - **애플리케이션 제한사항** 섹션:
     - **Android 앱** 선택
     - **+ 항목 추가** 클릭
     - 패키지 이름: `com.example.todo_calendar_demo`
     - SHA-1 인증서 지문: `AA:49:30:99:D5:F7:81:1E:40:CA:DC:F7:22:5F:AA:6D:1F:50:57:29`
   - **API 제한사항** 섹션:
     - **키 제한** 선택
     - **API 선택** 클릭
     - 다음 API만 선택:
       - Firebase Authentication API
       - Firebase Installations API
       - Identity Toolkit API
     - **저장** 클릭

   #### iOS용 API 키 제한
   - API 키 클릭하여 편집
   - **애플리케이션 제한사항** 섹션:
     - **iOS 앱** 선택
     - **+ 항목 추가** 클릭
     - Bundle ID: `com.example.todoCalendarDemo`
   - **API 제한사항** 섹션:
     - **키 제한** 선택
     - Firebase 관련 API만 선택
     - **저장** 클릭

   #### 웹용 API 키 제한
   - API 키 클릭하여 편집
   - **애플리케이션 제한사항** 섹션:
     - **HTTP 리퍼러(웹사이트)** 선택
     - **+ 항목 추가** 클릭
     - 다음 리퍼러만 추가:
       - `https://ordoo-ded2e.firebaseapp.com/*`
       - `https://ordoo-ded2e.web.app/*`
       - `http://localhost:*` (개발용)
   - **API 제한사항** 섹션:
     - **키 제한** 선택
     - Firebase 관련 API만 선택
     - **저장** 클릭

### 2단계: 노출된 API 키 교체 (필요한 경우)

만약 API 키가 공개 저장소에 노출되었다면:

1. **새 API 키 생성**
   - Google Cloud Console > APIs 및 서비스 > 사용자 인증 정보
   - **+ 자격증명 만들기** > **API 키**
   - 새 API 키 생성

2. **제한 설정 적용**
   - 위의 1단계와 동일하게 제한 설정

3. **기존 API 키 삭제 또는 제한**
   - 기존 API 키 삭제 또는 더 엄격한 제한 설정

### 3단계: 코드에서 웹용 API 키 분리 (선택사항)

웹용 Firebase API 키를 환경 변수로 분리하는 것을 권장합니다. 현재는 하드코딩되어 있지만, 빌드 시 주입하는 방법을 사용할 수 있습니다.

## 확인 사항

### ✅ 체크리스트

- [ ] 모든 API 키에 애플리케이션 제한 설정 완료
- [ ] 모든 API 키에 API 제한 설정 완료
- [ ] Android API 키에 패키지 이름 및 SHA-1 설정 완료
- [ ] iOS API 키에 Bundle ID 설정 완료
- [ ] 웹 API 키에 HTTP 리퍼러 제한 설정 완료
- [ ] 노출된 API 키 교체 완료 (필요한 경우)

## 주의사항

1. **google-services.json과 GoogleService-Info.plist**
   - 이 파일들은 앱에 포함되어야 하므로 Git에 커밋되는 것이 정상입니다
   - 하지만 API 키에 제한을 설정하여 악용을 방지해야 합니다

2. **웹용 Firebase API 키**
   - 웹에서는 클라이언트에 노출되므로 완전히 숨길 수 없습니다
   - HTTP 리퍼러 제한과 API 제한으로 보안을 강화해야 합니다

3. **서버를 통한 API 호출 (권장)**
   - 가장 안전한 방법은 서버를 통해 API를 호출하는 것입니다
   - 클라이언트에서는 서버 API만 호출하고, 서버에서 Google API를 호출합니다

## 참고 자료

- [Google API 키 보안 가이드](https://cloud.google.com/docs/authentication/api-keys)
- [Firebase 보안 모범 사례](https://firebase.google.com/docs/projects/best-practices)

