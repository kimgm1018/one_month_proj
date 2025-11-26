/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// 카카오톡 로그인을 위한 Custom Token 생성 함수
const admin = require("firebase-admin");
admin.initializeApp();

exports.createKakaoCustomToken = onRequest(async (req, res) => {
  // CORS 설정
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  try {
    const {kakaoUserId, kakaoAccessToken, kakaoEmail, kakaoNickname} = req.body;

    if (!kakaoUserId) {
      res.status(400).json({error: "카카오 사용자 ID가 필요합니다."});
      return;
    }

    // Firebase Custom Token 생성
    // UID는 'kakao:{kakaoUserId}' 형식으로 생성
    const uid = `kakao:${kakaoUserId}`;

    const customToken = await admin.auth().createCustomToken(uid);

    // Firestore에 사용자 정보 저장 (선택사항)
    await admin.firestore().collection("users").doc(uid).set({
      kakaoUserId: kakaoUserId,
      email: kakaoEmail || null,
      nickname: kakaoNickname || null,
      provider: "kakao",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    logger.info("카카오 Custom Token 생성 성공", {uid});
    res.status(200).json({customToken});
  } catch (error) {
    logger.error("Custom Token 생성 오류:", error);
    res.status(500).json({error: error.message});
  }
});
