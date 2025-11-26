# Firebase Functions 설정 가이드

카카오톡 로그인을 Firebase에 연동하기 위해 Firebase Functions를 설정하는 방법입니다.

## 1단계: Firebase Functions 프로젝트 초기화

```bash
# Firebase CLI 설치 (아직 안 했다면)
npm install -g firebase-tools

# Firebase 로그인
firebase login

# 프로젝트 루트에서 Functions 초기화
firebase init functions

# 선택 사항:
# - JavaScript 또는 TypeScript 선택
# - 기존 프로젝트 선택 또는 새 프로젝트 생성
```

## 2단계: Functions 코드 작성

`functions/index.js` 파일에 다음 코드를 추가하세요:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.createKakaoCustomToken = functions.https.onRequest(async (req, res) => {
  // CORS 설정
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const { kakaoUserId, kakaoAccessToken, kakaoEmail, kakaoNickname } = req.body;

    if (!kakaoUserId) {
      res.status(400).json({ error: '카카오 사용자 ID가 필요합니다.' });
      return;
    }

    // Firebase Custom Token 생성
    const uid = `kakao:${kakaoUserId}`;
    const customToken = await admin.auth().createCustomToken(uid);

    // Firestore에 사용자 정보 저장 (선택사항)
    await admin.firestore().collection('users').doc(uid).set({
      kakaoUserId: kakaoUserId,
      email: kakaoEmail || null,
      nickname: kakaoNickname || null,
      provider: 'kakao',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    res.status(200).json({ customToken });
  } catch (error) {
    console.error('Custom Token 생성 오류:', error);
    res.status(500).json({ error: error.message });
  }
});
```

## 3단계: Functions 배포

```bash
# Functions 배포
firebase deploy --only functions

# 배포 후 URL 확인
# 예: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createKakaoCustomToken
```

## 4단계: Flutter 앱에 URL 설정

`lib/services/auth_service.dart` 파일에서 `functionUrl`을 업데이트하세요:

```dart
const functionUrl = 'https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createKakaoCustomToken';
```

## 5단계: Firestore 보안 규칙 설정 (선택사항)

Firebase Console > Firestore Database > 규칙에서:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 참고사항

- Firebase Functions는 무료 할당량이 있습니다 (월 200만 호출)
- 프로덕션 환경에서는 카카오 토큰 검증을 추가하는 것이 좋습니다
- CORS 설정은 필요에 따라 조정하세요


