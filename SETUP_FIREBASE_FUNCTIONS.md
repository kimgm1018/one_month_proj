# Firebase Functions 설정 단계별 가이드

## 1단계: Firebase 로그인
터미널에서 다음 명령어 실행:
```bash
firebase login
```
브라우저가 열리면 Google 계정으로 로그인하세요.

## 2단계: Firebase Functions 초기화
프로젝트 루트 디렉토리에서:
```bash
cd /Users/kimgkangmin/Desktop/code/one_month_proj
firebase init functions
```

선택 사항:
- **Use an existing project** 선택
- 프로젝트 선택 (이미 만든 Firebase 프로젝트)
- **JavaScript** 선택 (TypeScript보다 간단)
- ESLint는 선택 안 해도 됨
- Functions 폴더는 기본값 `functions` 사용

## 3단계: Functions 코드 작성
`functions/index.js` 파일을 열고 다음 코드로 교체:

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
    // UID는 'kakao:{kakaoUserId}' 형식으로 생성
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

## 4단계: Functions 배포
```bash
firebase deploy --only functions
```

배포가 완료되면 다음과 같은 URL이 표시됩니다:
```
✔  functions[createKakaoCustomToken(us-central1)]: Successful create operation.
Function URL: https://us-central1-YOUR_PROJECT.cloudfunctions.net/createKakaoCustomToken
```

## 5단계: Flutter 앱에 URL 설정
`todo_calendar_demo/lib/services/auth_service.dart` 파일을 열고:

```dart
const functionUrl = 'https://us-central1-YOUR_PROJECT.cloudfunctions.net/createKakaoCustomToken';
```

위의 `YOUR_PROJECT`를 실제 프로젝트 ID로 변경하세요.

## 완료!
이제 카카오톡 로그인이 Firebase와 연동됩니다!


