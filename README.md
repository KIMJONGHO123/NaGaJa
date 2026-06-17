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

## Docker로 테스트하기 (처음부터 상세)

### 사전 준비

**필수 설치 목록:**

| 도구 | 설치 경로 | 확인 명령 |
|------|-----------|-----------|
| Docker Desktop | https://www.docker.com/products/docker-desktop/ | `docker --version` |
| Git | https://git-scm.com/ | `git --version` |

> **Windows 사용자**: Docker Desktop 설치 후 반드시 실행(트레이 아이콘 확인)해야 합니다.

---

### 1단계 — 저장소 클론

```bash
git clone <repository-url>
cd NaGaJa
```

클론 후 폴더 구조를 확인합니다:
```
NaGaJa/
├── Dockerfile
├── docker-compose.yml
├── .env.example       ← 이 파일이 있어야 합니다
└── NaGaJa/
    └── functions/
        └── data/
            └── bus-congestion-busan.csv   ← 혼잡도 데이터
```

---

### 2단계 — 환경 변수 설정

`.env.example`을 복사해 `.env`를 만들고 실제 API 키를 입력합니다.

**Windows (PowerShell):**
```powershell
copy .env.example .env
notepad .env
```

**macOS / Linux:**
```bash
cp .env.example .env
nano .env  # 또는 원하는 에디터로 열기
```

`.env` 파일 내용:
```env
WEATHER_SERVICE_KEY=발급받은_기상청_API_키
TMAP_APP_KEY=발급받은_TMAP_API_키
KAKAO_REST_API_KEY=발급받은_Kakao_REST_API_키
```

> API 키가 없어도 컨테이너는 실행됩니다. 단, 날씨·교통·지오코딩 단계에서 오류가 발생해 `generateDailyPlan`이 실패합니다.

---

### 3단계 — Docker 이미지 빌드 및 실행

```bash
docker compose up -d
```

처음 실행 시 이미지를 빌드하므로 **3~5분** 정도 걸립니다. 진행 상황을 보려면:

```bash
docker compose logs -f
```

빌드가 완료되고 에뮬레이터가 준비되면 아래와 같은 로그가 출력됩니다:
```
✔  All emulators ready! It is now safe to connect your app.
│  Emulator Host:Port                          │
│  Functions  nagaja-backend:5001              │
│  Firestore  nagaja-backend:8080              │
│  Auth       nagaja-backend:9099              │
│  Emulator UI nagaja-backend:4000             │
```

---

### 4단계 — 동작 확인

브라우저에서 아래 URL에 접속합니다:

| 서비스 | URL | 설명 |
|--------|-----|------|
| Firebase Emulator UI | http://localhost:4000 | 전체 에뮬레이터 대시보드 |
| Cloud Functions | http://localhost:5001 | 함수 엔드포인트 |
| Firestore | http://localhost:8080 | DB 에뮬레이터 |
| Auth | http://localhost:9099 | 인증 에뮬레이터 |

**Emulator UI(`http://localhost:4000`)에서 확인할 수 있는 것:**
- Firestore 탭 → 저장된 문서 조회/편집
- Authentication 탭 → 테스트 계정 추가
- Functions 탭 → 함수 호출 로그

---

### 5단계 — Cloud Functions 직접 테스트

Functions 베이스 URL:
```
http://localhost:5001/demo-nagaja/asia-northeast3
```

**`generateDailyPlan` 호출 예시 (curl):**
```bash
curl -X POST \
  "http://localhost:5001/demo-nagaja/asia-northeast3/generateDailyPlan" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-001",
    "planDate": "2026-01-01"
  }'
```

**Windows PowerShell:**
```powershell
Invoke-RestMethod `
  -Method POST `
  -Uri "http://localhost:5001/demo-nagaja/asia-northeast3/generateDailyPlan" `
  -ContentType "application/json" `
  -Body '{"userId":"test-user-001","planDate":"2026-01-01"}'
```

응답 예시:
```json
{
  "success": true,
  "results": [...]
}
```

---

### 6단계 — Firestore에서 결과 확인

1. http://localhost:4000 접속
2. **Firestore** 탭 클릭
3. `users` 컬렉션 → `test-user-001` → `dailyPlans` 서브컬렉션에서 계산된 플랜 확인

---

### 컨테이너 관리 명령어

```bash
# 백그라운드 실행
docker compose up -d

# 실시간 로그 보기
docker compose logs -f

# 컨테이너 상태 확인
docker compose ps

# 중지 (데이터 유지)
docker compose stop

# 완전 종료 및 컨테이너 삭제
docker compose down

# 이미지까지 삭제 후 처음부터 다시 빌드
docker compose down --rmi local
docker compose up -d --build
```

---

### 문제 해결

**포트 충돌 오류** (`port is already allocated`)
```bash
# 사용 중인 포트 확인 (Windows)
netstat -ano | findstr :4000
# 해당 PID 종료 후 재시도
```

**에뮬레이터가 시작되지 않음**
```bash
# 로그에서 오류 원인 확인
docker compose logs backend
```

**API 키 오류로 Functions 실패**  
날씨·교통 API 없이 기본 동작만 테스트할 경우 `.env`에 빈 값을 넣어도 컨테이너는 실행됩니다. `generateDailyPlan`은 실패하지만 Firestore/Auth 에뮬레이터 자체는 정상 동작합니다.

**이미지 재빌드가 필요한 경우** (소스 코드 수정 후)
```bash
docker compose up -d --build
```

---

## 전체 시스템 테스트 (Docker + 모바일 앱 + 라즈베리파이)

### 구성도

```
[PC / Mac]                        [Android 스마트폰]        [라즈베리파이 4]
Docker
 ├─ Firebase Auth    :9099  ←──── Flutter 앱              BLE 연동 예정
 ├─ Cloud Firestore  :8080  ←──── (동일 Wi-Fi)            (현재 미구현)
 └─ Cloud Functions  :5001  ←────
```

세 장치가 **같은 Wi-Fi 네트워크**에 있어야 합니다.

---

### 사전 준비

| 장치 | 필요 항목 |
|------|-----------|
| PC / Mac | Docker Desktop, Flutter SDK 3.x, Android Studio |
| Android 스마트폰 | 개발자 모드 ON, USB 디버깅 활성화, PC와 동일 Wi-Fi |
| 라즈베리파이 | Python 3, `firebase-admin` 패키지 (선택, 현재 BLE 미구현) |

---

### 1단계 — Docker 백엔드 실행

```bash
# 프로젝트 루트에서
cp .env.example .env    # .env에 실제 API 키 입력
docker compose up -d
```

에뮬레이터 준비 완료 메시지 확인:
```
✔  All emulators ready! It is now safe to connect your app.
```

---

### 2단계 — PC의 로컬 IP 확인

스마트폰이 PC의 에뮬레이터에 접속할 때 필요합니다.

**Windows:**
```powershell
ipconfig
# → IPv4 주소: 192.168.x.x  ← 이 값을 사용
```

**macOS / Linux:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

---

### 3단계 — Flutter 앱을 Docker 에뮬레이터에 연결

Flutter 앱은 기본적으로 프로덕션 Firebase(`nagaja-a6a8b`)에 연결됩니다.
Docker 에뮬레이터로 테스트하려면 `NaGaJa/lib/main.dart`의 `main()` 상단에 아래 코드를 추가합니다.

```dart
// main.dart 상단 import 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
```

`Firebase.initializeApp()` 바로 뒤에 삽입:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── 에뮬레이터 연결 (테스트 전용 — 완료 후 반드시 제거) ──
  if (kDebugMode) {
    const host = '192.168.x.x'; // 2단계에서 확인한 PC IP로 변경
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .useFunctionsEmulator(host, 5001);
  }
  // ─────────────────────────────────────────────────────────

  await AlarmService.instance.initialize();
  runApp(const NagajaApp());
}
```

> **주의**: 테스트가 끝나면 에뮬레이터 연결 블록을 제거하거나 주석 처리 후 커밋하세요. 그대로 두면 프로덕션에서 에뮬레이터로 접속을 시도합니다.

**더 간단한 대안**: 에뮬레이터 연결 코드 없이 `flutter run`하면 프로덕션 Firebase로 연결됩니다. 실제 Google 계정 로그인이 가능하고 날씨·교통 API도 동작하므로 기능 확인 목적이라면 이 방법이 더 빠릅니다.

---

### 4단계 — 앱을 스마트폰에 설치

USB로 스마트폰을 PC에 연결합니다.

```bash
cd NaGaJa
flutter devices        # 스마트폰이 목록에 표시되면 준비 완료
flutter pub get
flutter run            # 디버그 빌드로 설치 및 실행
```

빌드 완료 후 스마트폰 화면에 앱이 실행됩니다.

---

### 5단계 — 테스트 계정 준비 (에뮬레이터 모드)

에뮬레이터 모드에서는 Google Sign-In이 동작하지 않습니다. 이메일 계정을 미리 생성합니다.

1. `http://localhost:4000` → **Authentication** 탭 → **Add user**
2. Email: `test@test.com`, Password: `test1234` 입력 후 저장
3. 생성된 UID를 메모해 둡니다 (Firestore 확인 시 사용)

> 에뮬레이터 모드에서 앱 로그인 화면의 Google 버튼 대신 이메일 로그인이 필요한 경우 별도 구현이 필요합니다. 기능 테스트는 프로덕션 Firebase + 실제 Google 계정 로그인을 권장합니다.

---

### 6단계 — 전체 기능 플로우 테스트

#### 온보딩 (최초 1회)
1. 앱 실행 → Google 로그인
2. 이름, 준비 시간(분) 입력
3. 출발지 주소 검색 → 선택 (Kakao 지오코딩으로 좌표 저장)
4. 수업 시간표 등록: 요일, 수업 시작 시각, 목적지, 이동 수단
5. 홈 화면 진입 확인

#### 홈 화면 — dailyPlan 생성 및 확인
1. 홈 화면 우측 상단 **새로고침** 버튼 탭
2. `generateDailyPlan` Cloud Function 호출 → 날씨·교통·혼잡도 계산
3. 성공 시 카드 표시 확인:
   - **기상 알람** 카드 (finalAlarmTime)
   - **날씨 보정** 카드 (+N분, 맑음/비/눈)
   - **혼잡도 보정** 카드 (+N분)
4. `http://localhost:4000` Firestore 탭 → `users/{uid}/dailyPlans` 문서 생성 확인

#### 알람 전체화면 테스트
Firestore 에뮬레이터에서 `finalAlarmTime`을 **현재 시각 + 1~2분**으로 직접 수정합니다.

1. `http://localhost:4000` → Firestore → `users/{uid}/dailyPlans/{문서}` 클릭
2. `finalAlarmTime` 필드 → 현재 시각 + 1분으로 편집 (Timestamp 형식)
3. 앱이 30초 주기로 체크 → 지정 시각에 전체화면 알람 표시 확인
4. **알람 해제** 버튼 또는 배너 알람 "알람 해제" 탭으로 해제 확인

#### Wi-Fi 자동 출결 테스트
1. **설정** 탭 → Wi-Fi 출결 → 집 SSID / 학교 SSID 등록
2. 집 Wi-Fi 연결 상태에서 시작
3. Wi-Fi를 끄거나 다른 네트워크로 전환 → 홈 화면 "출발" 상태 자동 전환 확인
4. 학교 SSID 네트워크에 연결 → "도착" 자동 기록 확인
5. Firestore `dailyPlans` 문서 → `departedAt`, `arrivedAt` 필드 저장 확인

#### 캘린더 출결 확인
1. 하단 탭 → **캘린더**
2. 오늘 날짜 출결 상태 (정시 / 지각 / 결석) 표시 확인
3. **새로고침** 버튼 → Firestore 최신 데이터 반영 확인

---

### 7단계 — 라즈베리파이 알람시계

**동작 구조:**

```
[모바일 앱]  ──BLE──▶  [라즈베리파이]  ──Wi-Fi──▶  [Firestore]
               userId                  dailyPlans 실시간 구독
               (초기 1회 전달)          finalAlarmTime 감시
                                                │
                                          알람 시각 도달
                                                │
                                       LED 점등 + 부저 알람
```

- **BLE** (앱 → Pi): 앱 설정 화면의 "연결" 버튼을 누르면 `userId`를 Pi로 전송합니다. 초기 1회만 수행하면 Pi가 `user_id.txt`에 저장합니다.
- **Wi-Fi → Firestore** (Pi 상시): `userId`를 받은 Pi가 직접 Firestore의 `dailyPlans`를 실시간 구독해 `finalAlarmTime`에 GPIO로 물리 알람을 동작시킵니다.

---

**라즈베리파이 초기 설정:**

```bash
# 1. 시스템 패키지
sudo apt-get update
sudo apt-get install -y bluetooth bluez python3-pip

# 2. Python 의존성
cd raspberry_pi
pip3 install -r requirements.txt

# 3. Firebase 서비스 계정 키 배치
# Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성
# 다운로드한 파일을 raspberry_pi/serviceAccountKey.json 으로 저장
```

> `serviceAccountKey.json`은 절대 커밋하지 마세요 (`.gitignore`에 포함).

---

**라즈베리파이 실행 순서:**

```bash
# 터미널 1 — BLE 서버 (앱 연결 대기)
sudo python3 raspberry_pi/ble_receiver.py
# → "NaGaJa-Pi BLE GATT 서버 시작" 메시지 확인

# 터미널 2 — 알람 실행기 (Firestore 구독 + GPIO 제어)
python3 raspberry_pi/alarm_runner.py
# → userId가 없으면 "ble_receiver.py를 먼저 실행하세요" 안내 출력
```

---

**앱에서 연결:**

1. 앱 실행 → **설정** 탭 → **기기 연결** 섹션
2. **연결** 버튼 탭 → BLE 스캔 시작 (최대 10초)
3. `NaGaJa-Pi` 발견 시 자동 연결 → `userId` 전송
4. Pi 터미널에서 `[BLE] userId 수신 및 저장 완료: xxx` 로그 확인
5. `alarm_runner.py`가 실행 중이면 즉시 Firestore 구독 시작

---

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
