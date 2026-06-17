# 나가자 (NaGaJa)

Flutter + Firebase 기반 스마트 알람 · 출결 관리 앱입니다.
날씨·대중교통·혼잡도 데이터를 결합해 최적 출발 시각을 계산하고, Wi-Fi 자동 출결 로그 및 전체화면 알람을 제공합니다.

## 프로젝트 전체 구조 사진
<img width="2752" height="1536" alt="스마트_동적_알람_시스템_나가자" src="https://github.com/user-attachments/assets/a49532c7-33bb-48b7-ba01-82b2c15f2c90" />

---

## 기술 스택

| 구분 | 기술 |
|------|------|
| 모바일 앱 | Flutter 3.x (Dart), Android / iOS |
| 백엔드 | Firebase Cloud Functions (TypeScript, Node 20) |
| 데이터베이스 | Cloud Firestore |
| 인증 | Firebase Auth (Google 소셜 로그인) |
| 외부 API | 기상청 단기예보, TMAP 대중교통, Kakao 지오코딩 |
| 인프라 | Firebase (asia-northeast3), Raspberry Pi (Wi-Fi 출결) |
| 컨테이너 | Docker + Firebase Emulator Suite |

---

## 빠른 시작 (Docker)

> Docker Desktop이 설치되어 있어야 합니다.

```bash
# 1. 저장소 클론
git clone <repository-url>
cd NaGaJa

# 2. 환경 변수 설정
cp .env.example .env
# .env 파일을 열어 실제 API 키 입력

# 3. 백엔드(Firebase 에뮬레이터) 실행
docker compose up -d

# 4. 접속 확인
# Firebase Emulator UI : http://localhost:4000
# Cloud Functions      : http://localhost:5001
# Firestore Emulator   : http://localhost:8080
# Auth Emulator        : http://localhost:9099
```

종료:
```bash
docker compose down
```

---

## 환경 변수

`.env.example`을 복사해 `.env`를 만들고 아래 키를 입력합니다.

| 변수명 | 발급처 | 설명 |
|--------|--------|------|
| `WEATHER_SERVICE_KEY` | 공공데이터포털 | 기상청 단기예보 API 인증키 |
| `TMAP_APP_KEY` | SKT 개발자센터 | TMAP 대중교통 경로 API 키 |
| `KAKAO_REST_API_KEY` | Kakao Developers | 주소 → 좌표 변환(지오코딩) API 키 |

> `.env` 파일은 `.gitignore`에 의해 추적되지 않습니다. 실제 키를 커밋하지 마세요.

---

## API 엔드포인트

Cloud Functions 엔드포인트 목록 및 상세 문서는 [`NaGaJa/functions/docs/`](NaGaJa/functions/docs/) 를 참고합니다.

| 함수명 | 설명 |
|--------|------|
| `generateDailyPlan` | 일일 출발 계획 계산 (날씨+교통+혼잡도) |
| `getTransitData` | TMAP 대중교통 경로 조회 |
| `getWeatherData` | 기상청 단기예보 조회 |
| `getCongestionData` | 버스 혼잡도 계산 |

에뮬레이터 실행 시 Functions 베이스 URL:
```
http://localhost:5001/demo-nagaja/asia-northeast3/
```

---

## 테스트 계정

Firebase Auth 에뮬레이터 모드(`docker compose up -d`)로 실행 시 실제 Google 계정 없이 임의 계정을 생성할 수 있습니다.

- Emulator UI(`http://localhost:4000`) → Authentication 탭 → Add user
- 또는 앱에서 Google 로그인 진행 시 에뮬레이터가 자동으로 계정을 처리합니다.

---

## 모바일 앱 빌드

```bash
cd NaGaJa

# 의존성 설치
flutter pub get

# 기기/에뮬레이터에서 실행
flutter run

# Android APK 빌드
flutter build apk --release

# 코드 분석
flutter analyze
```

> Flutter SDK 3.x 이상, Android Studio (Android SDK 포함)가 필요합니다.

### Firebase 연결 (최초 1회)

```bash
firebase login
dart pub global run flutterfire_cli:flutterfire configure --platforms=android,ios
```

생성 파일: `NaGaJa/lib/firebase_options.dart`, `NaGaJa/android/app/google-services.json`

---

## 배포

### Cloud Functions 배포

```bash
cd NaGaJa/functions
npm install
npm run build
npm run deploy
# 또는: firebase deploy --only functions
```

### Firestore 규칙 배포

```bash
firebase deploy --only firestore:rules
```

> 배포 대상 Firebase 프로젝트: `nagaja-a6a8b` (Seoul, asia-northeast3)

---

## 프로젝트 구조

```text
NaGaJa/              (루트)
├── Dockerfile        # Firebase 에뮬레이터 Docker 이미지
├── docker-compose.yml
├── .env.example      # 환경 변수 템플릿
├── Mobile/           # Flutter 앱 안내 → NaGaJa/ 참조
├── Backend/          # Cloud Functions 안내 → NaGaJa/functions/ 참조
└── NaGaJa/           # Flutter 프로젝트 루트
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   ├── views/
    │   └── services/
    ├── functions/    # Cloud Functions (TypeScript)
    │   ├── src/
    │   └── docs/     # API 문서
    ├── android/
    └── ios/
```

---

## 로컬 개발 (Docker 없이)

### Cloud Functions 직접 실행

```bash
cd NaGaJa/functions
npm install
npm run build
npm run serve   # Firebase 에뮬레이터 시작
```

### iOS 관련

iOS 빌드/배포는 macOS + Xcode에서만 가능합니다.

```bash
cd NaGaJa/ios
pod install
open Runner.xcworkspace
```

---

## 보안/커밋 정책

다음 파일은 커밋하지 않습니다:

- `.env` (실제 API 키)
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `serviceAccountKey.json`

팀원은 각자 `flutterfire configure`를 실행해 Firebase 연결 파일을 생성해야 합니다.
