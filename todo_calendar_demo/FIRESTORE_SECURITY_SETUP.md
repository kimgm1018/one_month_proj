# 🔐 Firestore 보안 설정 가이드

## 개요

이제 보안 정보(OpenAI API 키 등)를 Firebase Firestore에 저장하여 관리합니다. 이렇게 하면:
- ✅ 코드에 하드코딩하지 않아도 됨
- ✅ 사용자별로 다른 API 키 저장 가능
- ✅ Firestore 보안 규칙으로 접근 제어
- ✅ 로컬 캐시로 오프라인 지원

## 1단계: Firestore 데이터베이스 생성

1. **Firebase Console 접속**
   - https://console.firebase.google.com
   - 프로젝트: `ordoo-ded2e` 선택

2. **Firestore Database 생성**
   - 좌측 메뉴: **Firestore Database**
   - **데이터베이스 만들기** 클릭
   - **프로덕션 모드** 또는 **테스트 모드** 선택 (초기에는 테스트 모드 권장)
   - 위치 선택 (예: `asia-northeast3` - 서울)

## 2단계: Firestore 보안 규칙 설정

Firebase Console > Firestore Database > 규칙 탭에서 다음 규칙을 설정하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 정보 컬렉션
    match /users/{userId} {
      // 사용자는 자신의 문서만 읽고 쓸 수 있음
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // 사용자 문서 내의 필드
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

### 보안 규칙 설명

- `request.auth != null`: 로그인된 사용자만 접근 가능
- `request.auth.uid == userId`: 자신의 문서만 접근 가능
- 다른 사용자의 API 키는 읽을 수 없음

## 3단계: 데이터 구조

Firestore에 다음과 같은 구조로 데이터가 저장됩니다:

```
users/
  {userId}/
    openaiApiKey: "sk-..."
    firebaseFunctionUrl: "https://..."
    updatedAt: Timestamp
```

## 4단계: 기본 API 키를 Firestore에 저장 (선택사항)

기본 API 키를 Firestore에 저장하려면:

1. **Firebase Console > Firestore Database > 데이터 탭**
2. **컬렉션 시작** 클릭
3. 컬렉션 ID: `users`
4. 문서 ID: `default` (또는 관리자 사용자 ID)
5. 필드 추가:
   - `openaiApiKey` (문자열): 기본 API 키 입력
   - `firebaseFunctionUrl` (문자열): Firebase Function URL

또는 코드에서 직접 저장할 수도 있습니다 (관리자 권한 필요).

## 5단계: 앱에서 사용

### API 키 저장
앱에서 API 키를 입력하면:
1. 로컬 캐시(SharedPreferences)에 저장
2. Firestore에 사용자별로 저장
3. 다음 로그인 시 자동으로 불러옴

### API 키 불러오기 순서
1. **Firestore에서 가져오기** (로그인된 사용자)
2. **로컬 캐시에서 가져오기** (오프라인 지원)
3. **기본값 사용** (Firestore와 로컬 캐시 모두 없을 때)

## 보안 권장 사항

### ✅ 권장 사항

1. **Firestore 보안 규칙 설정 필수**
   - 위의 보안 규칙을 반드시 적용하세요
   - 사용자는 자신의 데이터만 접근할 수 있어야 합니다

2. **프로덕션 모드 사용**
   - 초기 테스트 후 프로덕션 모드로 전환
   - 보안 규칙을 더 엄격하게 설정

3. **API 키 암호화 (선택사항)**
   - 민감한 정보는 클라이언트 측에서 암호화하여 저장
   - 또는 Firebase Functions를 통해 서버 측에서 관리

### ⚠️ 주의사항

1. **기본 API 키는 코드에 남아있음**
   - `secure_storage_service.dart`의 `defaultOpenAIApiKey`는 여전히 코드에 있습니다
   - Firestore에 저장하는 것을 권장합니다

2. **Firestore 비용**
   - Firestore는 읽기/쓰기 작업에 따라 비용이 발생합니다
   - 무료 할당량: 일일 50,000 읽기, 20,000 쓰기

3. **오프라인 지원**
   - 로컬 캐시를 사용하므로 오프라인에서도 작동합니다
   - 하지만 Firestore 동기화는 온라인일 때만 가능합니다

## 문제 해결

### Firestore 읽기/쓰기 권한 오류
- 보안 규칙이 올바르게 설정되었는지 확인
- 사용자가 로그인되어 있는지 확인

### API 키가 불러와지지 않음
- Firestore에 데이터가 저장되었는지 확인
- 로컬 캐시를 확인 (앱 재시작 후)
- 기본값이 설정되어 있는지 확인

## 참고 자료

- [Firestore 보안 규칙](https://firebase.google.com/docs/firestore/security/get-started)
- [Firestore 데이터 구조](https://firebase.google.com/docs/firestore/data-model)
- [Firestore 가격](https://firebase.google.com/pricing)

