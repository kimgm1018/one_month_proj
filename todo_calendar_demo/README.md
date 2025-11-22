# Ordoo - AI 기반 프로젝트 로드맵 생성 앱

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.7+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.7+-0175C2?logo=dart&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

**AI와 LangGraph를 활용한 지능형 프로젝트 계획 및 일정 관리 애플리케이션**

[기능 소개](#주요-기능) • [기술 스택](#기술-스택) • [시작하기](#시작하기) • [사용 방법](#사용-방법)

</div>

---

## 프로젝트 소개

**Ordoo**는 OpenAI GPT와 LangGraph 아키텍처를 활용하여 사용자의 자연어 요청으로부터 실행 가능한 프로젝트 로드맵을 자동 생성하는 Flutter 기반 모바일 애플리케이션입니다. 생성된 로드맵은 단계별 일정으로 분해되어 캘린더에 자동으로 할 일로 등록되며, 실시간 알림 기능을 통해 프로젝트 진행을 관리할 수 있습니다.

### 핵심 가치

- **AI 기반 자동 계획**: 복잡한 프로젝트를 자연어로 설명하면 AI가 단계별 실행 계획을 생성
- **스마트 일정 관리**: 생성된 로드맵이 자동으로 캘린더의 할 일로 변환
- **대화형 수정**: 채팅 인터페이스를 통해 로드맵을 실시간으로 수정 및 개선
- **크로스 플랫폼**: iOS, Android, Web, macOS, Windows 지원

---

## 주요 기능

### AI 로드맵 생성 (LangGraph 기반)

프로젝트의 핵심 기능으로, LangGraph의 상태 기반 워크플로우를 Flutter 앱에 통합하여 구현했습니다.

#### 작동 방식

1. **요구사항 분석 단계** (`analyzing`)
   - 사용자의 자연어 요청을 분석하여 프로젝트 목표, 기간, 주요 작업을 추출
   - OpenAI GPT API를 통해 구조화된 JSON 형식의 작업 명세 생성

2. **일정 스케줄링 단계** (`scheduling`)
   - 작업 간 의존성(dependencies)을 분석하여 최적의 시작/종료 날짜 계산
   - 선행 작업 완료를 고려한 타임라인 자동 생성

3. **요약 생성 단계** (`summarizing`)
   - 생성된 로드맵을 사용자 친화적인 자연어로 요약
   - 프로젝트 전체 흐름과 주요 마일스톤 설명

#### 기술적 특징

- **스트리밍 응답**: `Stream<RoadmapProgress>`를 통해 실시간 진행 상황 표시
- **에러 처리 및 재시도**: JSON 파싱 실패 시 자동 재시도 메커니즘 (최대 2회)
- **의존성 관리**: 작업 간 선후 관계를 고려한 스마트 스케줄링
- **세션 관리**: SQLite를 통한 로드맵 세션 및 채팅 히스토리 영구 저장

```dart
// 로드맵 생성 예시
final stream = RoadmapService.generateRoadmapStream(
  request: "1개월 안에 Flutter 앱 개발하기",
  apiKey: userApiKey,
  preferredStartDate: DateTime.now(),
);

await for (final progress in stream) {
  // 실시간 진행 상황 업데이트
  print('${progress.step}: ${progress.message}');
}
```

### 추가 기능

- **캘린더 통합**: `table_calendar` 패키지를 활용한 주간/2주 뷰 캘린더
- **알림 시스템**: `flutter_local_notifications`를 통한 시작/마감 알림
- **테마 관리**: 사용자 정의 색상 테마로 할 일 그룹화
- **데이터베이스**: SQLite 기반 로컬 데이터 영구 저장
- **다크 모드**: 라이트/다크 테마 지원

---

## 기술 스택

### 프론트엔드
- **Flutter 3.7+**: 크로스 플랫폼 UI 프레임워크
- **Dart 3.7+**: 프로그래밍 언어

### 백엔드 & AI
- **OpenAI GPT API**: 자연어 처리 및 로드맵 생성
- **LangGraph 아키텍처**: 상태 기반 워크플로우 설계 (Python 백엔드에서 구현, Flutter에서 동일한 로직 재현)

### 데이터베이스
- **SQLite (sqflite)**: 로컬 데이터 저장
- **path_provider**: 파일 시스템 접근

### 주요 패키지
```yaml
dependencies:
  table_calendar: ^3.1.3          # 캘린더 UI
  flutter_local_notifications: ^17.2.4  # 로컬 알림
  http: ^1.2.0                     # HTTP 통신
  sqflite: ^2.3.3                  # SQLite 데이터베이스
  intl: ^0.20.2                    # 국제화 및 날짜 포맷팅
  uuid: ^4.4.0                     # 고유 ID 생성
  flutter_colorpicker: ^1.1.0      # 색상 선택기
  flutter_markdown: ^0.7.4+1       # 마크다운 렌더링
```

---

## 시작하기

### 필수 요구사항

- Flutter SDK 3.7 이상
- Dart 3.7 이상
- OpenAI API 키 (로드맵 생성 기능 사용 시)

### 설치 방법

1. **저장소 클론**
```bash
git clone https://github.com/yourusername/one_month_proj.git
cd one_month_proj/todo_calendar_demo
```

2. **의존성 설치**
```bash
flutter pub get
```

3. **iOS 의존성 설치** (iOS 빌드 시)
```bash
cd ios
pod install
cd ..
```

4. **앱 실행**
```bash
flutter run
```

### 환경 설정

앱 내에서 OpenAI API 키를 설정해야 로드맵 생성 기능을 사용할 수 있습니다:
1. 앱 실행 후 로드맵 생성 버튼 클릭
2. 설정 아이콘에서 API 키 입력
3. OpenAI API 키 입력 (https://platform.openai.com/api-keys)

---

## 사용 방법

### 로드맵 생성하기

1. **로드맵 생성 버튼 클릭**
   - 화면 하단의 주황색 `+` 버튼 클릭

2. **프로젝트 요청 입력**
   - 자연어로 프로젝트 목표와 기간을 설명
   - 예: "1개월 안에 Flutter로 할 일 관리 앱 만들기"

3. **실시간 생성 과정 확인**
   - 요구사항 분석 → 일정 스케줄링 → 요약 생성 단계를 실시간으로 확인

4. **로드맵 검토 및 적용**
   - 생성된 로드맵 요약 확인
   - "할 일에 추가" 버튼으로 캘린더에 자동 등록

### 로드맵 수정하기

1. 기존 로드맵 세션 선택
2. 채팅 인터페이스에서 수정 요청 입력
3. AI가 수정된 로드맵 재생성

### 할 일 관리

- **추가**: 화면 하단의 검은색 `+` 버튼
- **수정/삭제**: 할 일 항목을 길게 눌러 메뉴 표시
- **완료**: 할 일 항목을 탭하여 완료 처리
- **알림 설정**: 할 일 추가 시 시작/마감 시간 설정 가능

---

## 프로젝트 구조

```
todo_calendar_demo/
├── lib/
│   ├── main.dart                 # 메인 앱 및 UI
│   ├── services/
│   │   ├── roadmap_service.dart  # 로드맵 생성 서비스 (LangGraph 로직)
│   │   └── notification_service.dart
│   ├── data/
│   │   ├── roadmap_repository.dart  # 로드맵 데이터 저장소
│   │   ├── todo_repository.dart
│   │   └── local_database.dart
│   └── models/
│       ├── todo_item.dart
│       └── todo_theme.dart
├── assets/
│   └── app_icon.png             # 앱 아이콘
├── ios/                          # iOS 네이티브 설정
├── android/                     # Android 네이티브 설정
└── pubspec.yaml                 # 프로젝트 설정 및 의존성
```

### 핵심 파일 설명

- **`roadmap_service.dart`**: LangGraph 기반 로드맵 생성 로직
  - `generateRoadmapStream()`: 스트리밍 방식 로드맵 생성
  - `_generateRoadmapWithRetry()`: 에러 처리 및 재시도 로직
  - `_buildSchedule()`: 의존성 기반 일정 스케줄링

- **`roadmap_repository.dart`**: 로드맵 세션 및 채팅 히스토리 관리
  - SQLite를 통한 영구 저장
  - 세션별 채팅 로그 관리

---

## 주요 구현 내용

### LangGraph 아키텍처 구현

Python의 LangGraph를 Flutter/Dart로 포팅하여 동일한 워크플로우를 구현했습니다:

```dart
// LangGraph의 StateGraph와 유사한 구조
enum RoadmapProgressStep {
  analyzing,      // 요구사항 분석
  generating,      // 작업 명세 생성
  scheduling,      // 일정 스케줄링
  summarizing,     // 요약 생성
  completed,       // 완료
}
```

### 스트리밍 응답 처리

OpenAI의 스트리밍 API를 활용하여 사용자 경험을 개선:

```dart
static Stream<RoadmapProgress> generateRoadmapStream({...}) async* {
  yield const RoadmapProgress(step: RoadmapProgressStep.analyzing, ...);
  // 각 단계마다 진행 상황을 스트림으로 전달
  yield const RoadmapProgress(step: RoadmapProgressStep.scheduling, ...);
  // ...
}
```

### 의존성 기반 스케줄링

작업 간 선후 관계를 고려한 최적 일정 계산:

```dart
static List<RoadmapTimelineEntry> _buildSchedule(
  List<RoadmapTaskSpec> tasks,
  DateTime startDate,
) {
  // 위상 정렬 알고리즘을 활용한 의존성 해결
  // 각 작업의 시작/종료 날짜 자동 계산
}
```

---

## 향후 계획

- [ ] 로드맵 프리뷰 기능: 생성 전 미리보기 및 수정 요청
- [ ] 기존 일정 반영: 현재 캘린더 일정을 고려한 로드맵 생성
- [ ] 협업 기능: 여러 사용자가 공유하는 로드맵
- [ ] 진행률 추적: 각 단계별 완료율 시각화
- [ ] 템플릿 기능: 자주 사용하는 프로젝트 템플릿 저장

---

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

---

## 개발자

프로젝트에 대한 질문이나 제안이 있으시면 이슈를 등록해 주세요.

---

<div align="center">

**Made with Flutter & LangGraph**

</div>
