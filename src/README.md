# 나가자 (NaGaJa) — 소스코드 실행 방법 및 아키텍처 가이드

---

## 시스템 아키텍처 설계

```
[Android 스마트폰]                [PC / 서버]                  [라즈베리파이 5]
                                                               
 Flutter 앱                       Docker                       nagaja_bridge.py
  ├─ 홈 화면 (출발 시각·알람)  ──▶  Firebase Auth  :9099        (Firestore 실시간 구독)
  ├─ 알람 (전체화면·배너)      ──▶  Cloud Firestore :8080  ──▶  WebSocket :8765
  ├─ 캘린더 (출결 기록)        ──▶  Cloud Functions :5001             │
  ├─ 설정 (Wi-Fi 출결·BLE)               │                    timer_ui.html
  └─ Wi-Fi 자동 출결 감지          generateDailyPlan         (Chromium 키오스크)
                                         │                         │
                              외부 API 호출                  GPIO 알람 발동
                               ├─ 기상청 단기예보             (부저 GPIO 18)
                               ├─ TMAP 대중교통
                               └─ Kakao 지오코딩

[연결 구조]
 Flutter 앱 ──BLE(userId, 최초 1회)──▶ 라즈베리파이 (사용자 등록)
 라즈베리파이 ──Wi-Fi──▶ Firestore (dailyPlans 실시간 구독 → 알람 시각 감시)
 nagaja_bridge.py ──WebSocket(8765)──▶ timer_ui.html (7인치 터치스크린 표시)
```

### 핵심 계산 흐름

```
targetArrivalTime (수업 시작 -5분)
        │
        ├── TMAP API → 경로 후보 최대 10개
        │      └── 각 경로별: 혼잡도 보정 + 날씨 보정 → predictedTravelMinutes
        │              (최솟값 경로 선택)
        │
        ├── finalDepartureTime = targetArrivalTime - predictedTravelMinutes
        └── finalAlarmTime     = finalDepartureTime - prepMinutes
```

### Firestore 주요 경로

```
users/{userId}
  └── schedules/{scheduleId}        # 수업 시간표
  └── dailyPlans/{date_scheduleId}  # 당일 출발 계획
        ├── finalAlarmTime          # 기상 알람 시각
        ├── finalDepartureTime      # 출발 시각
        ├── displayColor            # GREEN / YELLOW / RED
        ├── departedAt              # 실제 출발 시각
        └── arrivedAt               # 실제 도착 시각
```

---

## 기술 스택

| 구분 | 기술 |
|------|------|
| 모바일 앱 | Flutter 3.x (Dart), Android / iOS |
| 백엔드 | Firebase Cloud Functions (TypeScript, Node 20) |
| 데이터베이스 | Cloud Firestore |
| 인증 | Firebase Auth (Google 소셜 로그인) |
| 외부 API | 기상청 단기예보, TMAP 대중교통, Kakao 지오코딩 |
| IoT | Raspberry Pi 5, 7인치 공식 터치스크린, 부저 (GPIO 18) |
| IoT 브리지 | firebase-admin (Python), websockets, RPi.GPIO |
| BLE | flutter_blue_plus (Flutter) / bless (Python GATT 서버, Pi 측 userId 수신) |
| 컨테이너 | Docker + Firebase Emulator Suite |
| Firebase 프로젝트 | nagaja-a6a8b (asia-northeast3, 서울) |

---

## 환경 변수

`.env.example`을 복사해 `.env`를 만들고 아래 키를 입력합니다.

```bash
cp .env.example .env
```

| 변수명 | 발급처 | 설명 |
|--------|--------|------|
| `WEATHER_SERVICE_KEY` | 공공데이터포털 | 기상청 단기예보 API 인증키 |
| `TMAP_APP_KEY` | SKT 개발자센터 | TMAP 대중교통 경로 API 키 |
| `KAKAO_REST_API_KEY` | Kakao Developers | 주소 → 좌표 변환(지오코딩) API 키 |

> `.env` 파일은 `.gitignore`로 추적에서 제외됩니다. 실제 키를 커밋하지 마세요.

---

## API 엔드포인트

상세 문서: [`NaGaJa/functions/docs/`](../NaGaJa/functions/docs/)

| 함수명 | 설명 |
|--------|------|
| `generateDailyPlan` | 일일 출발 계획 계산 (날씨 + 교통 + 혼잡도) |
| `getTransitData` | TMAP 대중교통 경로 조회 |
| `getWeatherData` | 기상청 단기예보 조회 |
| `getCongestionData` | 버스 혼잡도 계산 |

에뮬레이터 실행 시 Functions 베이스 URL:
```
http://localhost:5001/demo-nagaja/asia-northeast3/
```

---

## Docker로 백엔드 실행하기

### 사전 준비

| 도구 | 설치 경로 | 확인 명령 |
|------|-----------|-----------|
| Docker Desktop | https://www.docker.com/products/docker-desktop/ | `docker --version` |
| Git | https://git-scm.com/ | `git --version` |

> **Windows**: Docker Desktop 설치 후 트레이 아이콘에서 실행 중인지 확인합니다.

### 1단계 — 저장소 클론

```bash
git clone <repository-url>
cd NaGaJa
```

### 2단계 — 환경 변수 설정

**Windows (PowerShell):**
```powershell
copy .env.example .env
notepad .env
```

**macOS / Linux:**
```bash
cp .env.example .env
nano .env
```

### 3단계 — 빌드 및 실행

```bash
docker compose up -d
```

처음 실행 시 이미지 빌드로 3~5분 소요됩니다. 로그 확인:

```bash
docker compose logs -f
```

준비 완료 시 출력:
```
✔  All emulators ready! It is now safe to connect your app.
```

### 4단계 — 동작 확인

| 서비스 | URL |
|--------|-----|
| Firebase Emulator UI | http://localhost:4000 |
| Cloud Functions | http://localhost:5001 |
| Firestore | http://localhost:8080 |
| Auth | http://localhost:9099 |

### 5단계 — Cloud Functions 테스트

```bash
curl -X POST \
  "http://localhost:5001/demo-nagaja/asia-northeast3/generateDailyPlan" \
  -H "Content-Type: application/json" \
  -d '{"userId": "test-user-001", "planDate": "2026-01-01"}'
```

**Windows PowerShell:**
```powershell
Invoke-RestMethod `
  -Method POST `
  -Uri "http://localhost:5001/demo-nagaja/asia-northeast3/generateDailyPlan" `
  -ContentType "application/json" `
  -Body '{"userId":"test-user-001","planDate":"2026-01-01"}'
```

### 컨테이너 관리

```bash
docker compose up -d          # 백그라운드 실행
docker compose logs -f        # 실시간 로그
docker compose ps             # 상태 확인
docker compose stop           # 중지 (데이터 유지)
docker compose down           # 완전 종료
docker compose up -d --build  # 소스 수정 후 재빌드
```

### 문제 해결

**포트 충돌** (`port is already allocated`)
```bash
netstat -ano | findstr :4000   # Windows — 사용 중인 PID 확인 후 종료
```

**에뮬레이터 시작 실패**
```bash
docker compose logs backend
```

**API 키 없이 테스트**: `.env`에 빈 값을 넣어도 컨테이너는 실행됩니다. `generateDailyPlan`은 실패하지만 Firestore/Auth 에뮬레이터 자체는 동작합니다.

---

## 전체 시스템 테스트 (Docker + 모바일 앱 + 라즈베리파이)

### 구성도

```
[PC / Mac]                        [Android 스마트폰]        [라즈베리파이 5]
Docker
 ├─ Firebase Auth    :9099  ←──── Flutter 앱  ─BLE(최초 1회)→ userId 수신
 ├─ Cloud Firestore  :8080  ←──── (동일 Wi-Fi)             nagaja_bridge.py
 └─ Cloud Functions  :5001  ←────                          (Firestore 구독)
                                                                 │
                                                           WebSocket :8765
                                                                 │
                                                          timer_ui.html (7인치)
                                                                 │
                                                            GPIO 부저/버튼
```

### 사전 준비

| 장치 | 필요 항목 |
|------|-----------|
| PC / Mac | Docker Desktop, Flutter SDK 3.x, Android Studio |
| Android 스마트폰 | 개발자 모드 ON, USB 디버깅 활성화, PC와 동일 Wi-Fi, Bluetooth ON |
| 라즈베리파이 5 | Python 3, bluetooth/bluez, bless, firebase-admin, websockets, RPi.GPIO, 7인치 공식 터치스크린 |

### 1단계 — Docker 백엔드 실행

위의 "Docker로 백엔드 실행하기" 섹션을 완료합니다.

### 2단계 — PC 로컬 IP 확인 (스마트폰 연결 시)

**Windows:**
```powershell
ipconfig
# IPv4 주소: 192.168.x.x
```

**macOS / Linux:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### 3단계 — Flutter 앱을 Docker 에뮬레이터에 연결 (선택)

기본 앱은 프로덕션 Firebase에 연결됩니다. Docker 에뮬레이터로 테스트하려면
`NaGaJa/lib/main.dart`의 `Firebase.initializeApp()` 직후에 아래 코드를 추가합니다.

```dart
// main.dart 상단 import 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Firebase.initializeApp() 직후 삽입
if (kDebugMode) {
  // 실제 스마트폰: PC 로컬 IP 사용
  // Android 에뮬레이터: 10.0.2.2 사용
  const host = '192.168.x.x';
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFunctions.instanceFor(region: 'asia-northeast3')
      .useFunctionsEmulator(host, 5001);
}
```

> 테스트 완료 후 반드시 제거하거나 주석 처리하세요.

### 4단계 — 앱 실행

#### 방법 A: 실제 스마트폰 (BLE·Wi-Fi 기능 테스트 가능)

```bash
cd NaGaJa
flutter devices   # 스마트폰이 목록에 표시되면 준비 완료
flutter pub get
flutter run
```

#### 방법 B: Android Studio 에뮬레이터 (BLE·Wi-Fi SSID 미지원)

1. Android Studio → **Device Manager** → **Create Virtual Device**
2. Pixel 7 선택 → API 34 (Android 14) → Finish → ▶ 실행
3. `host`를 `10.0.2.2`로 변경 후:

```bash
cd NaGaJa
flutter devices   # emulator-XXXX 항목 확인
flutter pub get
flutter run
```

**기능 제한 비교:**

| 기능 | 에뮬레이터 | 실제 기기 |
|------|-----------|---------|
| Firebase Auth / Firestore / Functions | 동작 | 동작 |
| 알람 (로컬 알림) | 동작 | 동작 |
| Wi-Fi SSID 자동 출결 | 미동작 | 동작 |
| BLE (라즈베리파이 연결) | 미동작 | 동작 |

### 5단계 — 전체 기능 플로우 테스트

**온보딩**: Google 로그인 → 이름·준비시간 입력 → 출발지·목적지 주소 검색 → 수업 시간표 등록

**홈 화면**: 새로고침 버튼 → `generateDailyPlan` 호출 → 기상 알람·날씨·혼잡도 카드 확인

**알람 테스트**: Emulator UI(`http://localhost:4000`) → Firestore → `dailyPlans` 문서의 `finalAlarmTime`을 현재 시각 + 1분으로 편집 → 전체화면 알람 확인

**Wi-Fi 출결**: 설정 → Wi-Fi 출결 → 집/학교 SSID 등록 → 네트워크 전환으로 자동 출발·도착 확인

**캘린더**: 하단 캘린더 탭 → 정시/지각/결석 표시 확인

### 6단계 — 라즈베리파이 5 알람시계

라즈베리파이 알람시계는 별도 Git 저장소에 있습니다:
**`https://github.com/jeje9893/NaGaJa-raspi`**

**동작 구조:**

```
[최초 1회] Flutter 앱 ──BLE──▶ 라즈베리파이 (userId 전달 → nagaja_bridge.py 기동)
[이후 상시] Firestore (dailyPlans) ──Wi-Fi──▶ nagaja_bridge.py ──WebSocket(8765)──▶ timer_ui.html
                                                    │                               (7인치 Chromium)
                                              알람 시각 도달
                                                    │
                                             GPIO 부저 알람 (핀 18)
                                             버튼으로 해제 (핀 17)
```

**GPIO 배선:**

| 구성요소 | GPIO 핀 |
|----------|---------|
| 부저 (Buzzer) | GPIO 18 |
| 버튼 (Button) | GPIO 17 |

**Pi 초기 설정:**

```bash
# 1. 라즈베리파이 프로젝트 클론
git clone https://github.com/jeje9893/NaGaJa-raspi.git ~/nagaja
cd ~/nagaja

# 2. Bluetooth 패키지 설치
sudo apt-get update
sudo apt-get install -y bluetooth bluez python3-pip

# 3. Python 가상환경 생성 및 패키지 설치
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt   # firebase-admin, websockets, bless
pip install RPi.GPIO

# 4. Firebase 서비스 계정 키 배치 (절대 커밋 금지)
# Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성
# → ~/nagaja/serviceAccountKey.json 으로 저장
```

**Pi 실행 (수동):**

```bash
cd ~/nagaja
source venv/bin/activate

# 터미널 1 — BLE GATT 서버 (앱에서 userId 수신 대기, 최초 1회)
sudo python3 ble_receiver.py
# 앱 설정 탭 → 기기 연결 → 연결 버튼 → userId 자동 전송

# userId 수신 후 터미널 2 — Firestore 브리지 + GPIO
python3 nagaja_bridge.py

# 터미널 3 — 7인치 터치스크린 UI (Chromium 키오스크)
chromium-browser --kiosk --disable-infobars \
  --window-size=800,480 \
  http://localhost:8765
```

**앱에서 연결**: 설정 탭 → 기기 연결 → **연결** 버튼 → `NaGaJa-Pi` 자동 스캔 및 userId 전송

**systemd 자동 시작 (부팅 시 자동 실행):**

```bash
# 서비스 파일 등록
sudo cp nagaja-bridge.service /etc/systemd/system/
sudo systemctl enable nagaja-bridge
sudo systemctl start nagaja-bridge

# 상태 확인
sudo systemctl status nagaja-bridge
```

Chromium 키오스크도 `/etc/xdg/autostart/nagaja-ui.desktop`으로 부팅 시 자동 시작됩니다.

---

## 모바일 앱 빌드

```bash
cd NaGaJa
flutter pub get

flutter run                  # 디버그 실행
flutter build apk --release  # Android 릴리즈 APK
flutter analyze              # 코드 분석
```

> Flutter SDK 3.x 이상, Android Studio (Android SDK 포함) 필요

### Firebase 연결 (최초 1회)

```bash
firebase login
dart pub global run flutterfire_cli:flutterfire configure --platforms=android,ios
```

생성 파일: `NaGaJa/lib/firebase_options.dart`, `NaGaJa/android/app/google-services.json`

### iOS 빌드 (macOS 전용)

```bash
cd NaGaJa/ios
pod install
open Runner.xcworkspace
```

---

## 배포

### Cloud Functions

```bash
cd NaGaJa/functions
npm install
npm run build
firebase deploy --only functions
```

### Firestore 규칙

```bash
firebase deploy --only firestore:rules
```

> 배포 대상: `nagaja-a6a8b` (asia-northeast3, 서울)

---

## 로컬 개발 (Docker 없이)

```bash
cd NaGaJa/functions
npm install
npm run build
npm run serve   # Firebase 에뮬레이터 직접 실행
```

---

## 보안/커밋 정책

다음 파일은 커밋하지 않습니다:

- `.env` (API 키)
- `NaGaJa/android/app/google-services.json`
- `NaGaJa/ios/Runner/GoogleService-Info.plist`
- `raspberry_pi/serviceAccountKey.json`

팀원은 각자 `flutterfire configure`를 실행해 Firebase 연결 파일을 생성해야 합니다.
