// Firebase Functions 예시 코드
// 이 파일은 참고용이며, 실제로는 Firebase Functions 프로젝트에 배포해야 합니다.

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// 카카오 로그인을 위한 Custom Token 생성 함수
exports.createKakaoCustomToken = functions.https.onRequest(async (req, res) => {
  // CORS 설정 (필요한 경우)
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

    // 카카오 액세스 토큰 검증 (선택사항)
    // 실제로는 카카오 API를 호출하여 토큰이 유효한지 확인해야 합니다.
    // const kakaoUserInfo = await verifyKakaoToken(kakaoAccessToken);

    // Firebase Custom Token 생성
    // UID는 'kakao:{kakaoUserId}' 형식으로 생성하여 고유성을 보장
    const uid = `kakao:${kakaoUserId}`;
    
    // Custom Claims에 카카오 정보 추가 (선택사항)
    const customClaims = {
      provider: 'kakao',
      kakaoUserId: kakaoUserId,
    };

    const customToken = await admin.auth().createCustomToken(uid, customClaims);

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

// 카카오 토큰 검증 함수 (선택사항)
async function verifyKakaoToken(accessToken) {
  const response = await fetch('https://kapi.kakao.com/v2/user/me', {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
    },
  });
  
  if (!response.ok) {
    throw new Error('카카오 토큰 검증 실패');
  }
  
  return await response.json();
}


