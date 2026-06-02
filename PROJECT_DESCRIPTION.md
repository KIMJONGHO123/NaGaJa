# 나가자 (NaGaJa) — 프로젝트 설명서

물리 알람시계 등 외부 기기 연동을 위한 프로젝트 구조 및 데이터 명세입니다.

---

## 개요

**나가자**는 대학생을 위한 스마트 알람 · 출결 관리 앱입니다.  
수업 시간표, 이동 경로, 날씨, 대중교통 혼잡도를 종합해 **최적 기상/출발 시각을 자동 계산**합니다.

- 플랫폼: Flutter (Android / iOS)
- 백엔드: Firebase (Firestore, Authentication, Cloud Functions)
- 리전: `asia-northeast3` (서울)
- Firebase 프로젝트 ID: `nagaja-a6a8b`

---

## 핵심 개념

| 용어 | 설명 |
|------|------|
| `prepMinutes` | 알람 울린 후 실제 출발까지 걸리는 준비 시간 (기본 30분) |
| `defaultTravelMinutes` | 기본 이동 시간 (기본 20분) |
| `finalAlarmTime` | **알람시계가 울려야 할 시각** = 목표 도착 시각 − 예측 이동 시간 − 준비 시간 |
| `finalDepartureTime` | 출발해야 할 시각 = 목표 도착 시각 − 예측 이동 시간 |
| `displayColor` | 시간 여유 상태: `GREEN` (여유) / `YELLOW` (주의) / `RED` (위험) |
| `planStatus` | `CALCULATED` (정상 계산) / `FALLBACK` (로컬 폴백) |

---

## Firestore 데이터 구조

### 1. 사용자 문서 — `users/{userId}`

```
users/
  {userId}/
    userId          : String   — Firebase Auth UID
    name            : String   — 사용자 이름
    email           : String   — 이메일
    prepMinutes     : int      — 준비 시간 (분)
    defaultTravelMinutes : int — 기본 이동 시간 (분)
    homeWifiSsids   : String[] — 집 Wi-Fi SSID 목록
    schoolWifiSsids : String[] — 학교 Wi-Fi SSID 목록
    createdAt       : Timestamp
    updatedAt       : Timestamp
```

### 2. 수업 일정 — `users/{userId}/schedules/{scheduleId}`

```
schedules/
  {scheduleId}/
    scheduleId          : String   — 문서 ID와 동일
    userId              : String
    title               : String   — 과목명 (예: "자료구조")
    dayOfWeek           : int      — 1=월 ~ 7=일
    classTime           : String   — "HH:MM" 수업 시작 시각
    targetArrivalTime   : String   — "HH:MM" 목표 도착 시각
    startPlaceName      : String   — 출발지 이름 (예: "집")
    startAddress        : String   — 출발지 주소
    startLat            : double?  — 출발지 위도 (백엔드 계산)
    startLng            : double?  — 출발지 경도 (백엔드 계산)
    destinationName     : String   — 목적지 이름 (예: "공학관")
    destinationAddress  : String   — 목적지 주소
    endLat              : double?  — 목적지 위도
    endLng              : double?  — 목적지 경도
    transportMode       : String   — "BUS" | "SUBWAY" | "WALK"
    isActive            : bool     — 비활성화된 일정은 false
    createdAt           : Timestamp
    updatedAt           : Timestamp
```

### 3. 오늘의 플랜 — `users/{userId}/dailyPlans/{planId}`

**알람시계가 주로 참조해야 할 컬렉션입니다.**

```
dailyPlans/
  {planId}/
    dailyPlanId             : String
    scheduleId              : String   — schedules 문서 ID 참조
    planDate                : String   — "YYYY-MM-DD" (KST 기준)
    title                   : String   — 과목명
    dayOfWeek               : int
    classTime               : String   — "HH:MM"
    targetArrivalTime       : String   — "HH:MM"

    finalAlarmTime          : Timestamp  ★ 알람 시각 (알람시계 핵심 값)
    finalDepartureTime      : Timestamp  ★ 출발 시각
    baseAlarmTime           : Timestamp  — 혼잡/날씨 보정 전 원래 알람 시각
    baseDepartureTime       : Timestamp

    prepMinutes             : int      — 준비 시간
    defaultTravelMinutes    : int      — 기본 이동 시간
    predictedTravelMinutes  : int      — 예측 이동 시간 (날씨/혼잡도 반영)
    congestionAdjustMinutes : int      — 혼잡도 보정 시간 (+이면 늦어짐)
    weatherAdjustMinutes    : int      — 날씨 보정 시간
    weatherType             : String   — "CLEAR" | "RAIN" | "SNOW" 등
    remainingMarginMinutes  : int      — 현재 시각 기준 여유 시간

    displayColor            : String   — "GREEN" | "YELLOW" | "RED"
    planStatus              : String   — "CALCULATED" | "FALLBACK"
    fallbackUsed            : bool     — Cloud Function 실패 시 로컬 계산 여부

    calculationTime         : Timestamp
    createdAt               : Timestamp
    updatedAt               : Timestamp
```

### 4. 기타 서브컬렉션

```
users/{userId}/arrivalLogs/{logId}
  arrivedAt   : Timestamp
  scheduleId  : String?
  createdAt   : Timestamp

users/{userId}/prepLogs/{logId}
  startedAt     : Timestamp
  departedAt    : Timestamp
  scheduleId    : String?
  actualMinutes : int
  createdAt     : Timestamp
```

---

## Cloud Functions API

베이스 URL: `https://asia-northeast3-nagaja-a6a8b.cloudfunctions.net`

모든 요청은 `Content-Type: application/json`, POST 방식.  
인증이 필요한 엔드포인트는 `Authorization: Bearer {Firebase ID Token}` 헤더 포함.

### `POST /generateDailyPlan` ★ 핵심 함수

날씨 + 대중교통 혼잡도를 반영해 `dailyPlans` 문서를 생성/갱신합니다.  
알람시계에서 알람 시각을 갱신하고 싶을 때 호출하면 됩니다.

**Request Body**
```json
{
  "userId": "Firebase UID",
  "scheduleId": "선택 — 특정 수업만 계산할 때"
}
```

**Response** `200 OK`  
성공 시 Firestore `dailyPlans`에 문서가 생성/갱신됩니다.

---

### `POST /getTransitData`

특정 유저의 첫 번째 활성 스케줄로 대중교통 경로를 조회합니다.

```json
{ "userId": "Firebase UID", "routeNo": "버스 노선번호(선택)" }
```

---

### `POST /getCongestionData`

버스 노선 혼잡도를 계산합니다.

```json
{ "routeNo": "버스 노선번호", "departureAt": "2025-01-01T08:00:00" }
```

---

### `POST /getWeatherData`

출발지 기준 날씨를 조회합니다.

```json
{ "userId": "Firebase UID" }
```

---

## 알람시계 연동 흐름

```
1. Firebase Auth 로그인 → ID Token 획득
2. POST /generateDailyPlan  →  dailyPlans 문서 생성/갱신
3. Firestore 읽기:
     users/{uid}/dailyPlans
       where planDate == "오늘 날짜(YYYY-MM-DD, KST)"
4. finalAlarmTime (Timestamp) → 알람 시각으로 설정
5. displayColor 으로 LED 색상 표시 (GREEN/YELLOW/RED)
```

> **주의**: 날짜는 **KST(UTC+9)** 기준입니다.  
> `planDate` 필드는 `"YYYY-MM-DD"` 문자열이며, UTC 자정이 아닌 KST 자정 기준으로 생성됩니다.

---

## displayColor 판단 기준

앱 내 상태(HomeScreen) 기준으로 남은 시간을 계산합니다.

| 조건 | displayColor |
|------|-------------|
| 여유 시간 > 이동시간 + 10분 | `GREEN` |
| 여유 시간 > 이동시간 + 5분  | `YELLOW` |
| 그 외 (지각 위험)           | `RED` |

---

## 인증 방식

Firebase Authentication (Google 소셜 로그인 기반).  
Cloud Functions 호출 시 `Authorization: Bearer <idToken>` 헤더 필요.  
ID Token은 1시간마다 갱신됩니다.

---

## 타임존

- 앱 및 Cloud Functions 모두 **KST (UTC+9)** 기준으로 날짜를 계산합니다.
- Firestore Timestamp는 UTC로 저장되므로, 읽을 때 +9시간 변환이 필요합니다.
- `planDate` 문자열(`"YYYY-MM-DD"`)은 KST 기준입니다.

---

## 백그라운드 유지 기능 (Keep-Alive)

Wi-Fi 감지·기상 알람 등 백그라운드 동작을 위해 앱이 종료되지 않도록 유지하는 기능입니다.

### 동작 원리

OS는 배터리 절약을 위해 백그라운드 앱을 강제 종료합니다.  
이를 막기 위해 **"오디오를 재생 중인 앱"** 임을 OS에 알려 프로세스를 보호합니다.

- **Android**: 포그라운드 서비스(Foreground Service) + 무음 오디오 루프
- **iOS**: `UIBackgroundModes: [audio]` + 무음 오디오 루프

포그라운드 서비스는 알림창에 **"나가자 실행 중"** 알림을 표시합니다(Android 8+ 필수 요건).  
이 알림이 있는 동안 OS는 해당 프로세스를 보호합니다.

### 구현 구조

```
앱 백그라운드 전환 (AppLifecycleState.paused)
  │
  ├─ [Android] MethodChannel → SilentAudioForegroundService 시작
  │    ├─ 알림 표시: "나가자 실행 중" (IMPORTANCE_LOW, 무진동)
  │    ├─ WakeLock 획득 (PARTIAL_WAKE_LOCK, 최대 1시간)
  │    └─ MediaPlayer로 silence.mp3 루프 재생 (볼륨 0)
  │
  └─ [공통] audioplayers로 silence.mp3 루프 재생 (볼륨 0)
       iOS: AVAudioSession.category = .playback 자동 설정

앱 포그라운드 복귀 (AppLifecycleState.resumed)
  └─ 서비스 중지, 오디오 중지, 알림 사라짐
```

### 관련 파일

| 파일 | 역할 |
|------|------|
| `lib/services/background_audio_service.dart` | Dart 싱글턴. start()/stop() 제공 |
| `android/.../SilentAudioForegroundService.kt` | Android 포그라운드 서비스 네이티브 코드 |
| `android/.../MainActivity.kt` | MethodChannel 핸들러 (`startService`/`stopService`) |
| `assets/audio/silence.mp3` | 1초짜리 무음 MP3 (audioplayers용) |
| `ios/Runner/Info.plist` | `UIBackgroundModes: [audio]` 선언 |

### Android 권한 (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### 주의사항

- 삼성·샤오미 등 일부 제조사는 배터리 최적화 설정으로 포그라운드 서비스도 종료할 수 있습니다.  
  앱 배터리 최적화 예외 설정을 사용자에게 안내하는 것이 권장됩니다.
- `silence.mp3`의 Android 네이티브 접근 경로: `flutter_assets/assets/audio/silence.mp3`  
  (APK 내부에서 Flutter 에셋은 `flutter_assets/` 접두사로 패키징됨)

---

## 기상 알람 기능

`finalAlarmTime`에 정확히 알람음을 울리고 사용자가 해제할 수 있는 기능입니다.

### 동작 원리

두 개의 레이어가 병렬로 동작합니다:

| 레이어 | 방법 | 역할 |
|--------|------|------|
| **1차 (OS 예약)** | `flutter_local_notifications` `zonedSchedule` | 앱이 죽어도 OS가 정시에 알림 배너 발사 |
| **2차 (앱 내 타이머)** | 30초 주기 Dart 타이머 + RingtoneManager | 앱이 살아있을 때 알람음 루프 재생 |

백그라운드 유지 기능이 앱을 살려두기 때문에 2차 레이어가 대부분의 경우 동작합니다.

### 알람 발화 흐름

```
앱 시작 → AlarmService.initialize()  (알림 채널 생성, timezone 초기화)
홈 화면 로드 → DailyPlan 로드 후 scheduleAlarm(finalAlarmTime)
  │
  ├─ OS AlarmManager에 exact alarm 등록 (alarmClock 모드, DND 우회)
  └─ Dart 30초 타이머 시작 (앱 시작 시점부터 항상 실행)

finalAlarmTime 도달:
  앱 살아있음 → _check() 감지 → _fireAlarm()
    └─ MethodChannel → MainActivity.playAlarmSound()
         └─ RingtoneManager.getRingtone(TYPE_ALARM).play()  (기기 기본 알람음, 루프)

  앱 죽어있음 → OS 알림 배너 발사 + 알림음 1회

알람 해제:
  알림창 "알람 해제" 버튼 → _onNotificationTap → dismissAlarm()
  앱 화면 상단 빨간 배너 → "알람 해제" 버튼 → dismissAlarm()
    └─ RingtoneManager.stop() + 알림 취소 + _fired = false
```

### OS 알림 채널 설정

```
channelId: 'nagaja_alarm'
importance: Importance.max
audioAttributesUsage: AudioAttributesUsage.alarm  → DND(방해금지) 우회
                                                   → 알람 볼륨 슬라이더 제어
```

### 관련 파일

| 파일 | 역할 |
|------|------|
| `lib/services/alarm_service.dart` | AlarmService 싱글턴. initialize/scheduleAlarm/dismissAlarm |
| `android/.../MainActivity.kt` | `playAlarmSound`/`stopAlarmSound` MethodChannel 핸들러 (RingtoneManager 호출) |
| `lib/views/home/home_screen.dart` | `_scheduleAlarmIfNeeded()` 예약 호출, `_alarmDismissBanner()` 해제 UI |
| `lib/main.dart` | 앱 시작 시 `AlarmService.initialize()` + `startChecking()` |

### Android 권한 (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>      <!-- API 33+, 런타임 동의 불필요 -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/> <!-- 재부팅 후 알람 재예약 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>    <!-- API 33+, 알림 표시 권한 -->
```

### 알람 해제 UI

알람이 발화하면(`AlarmService.isAlarmFired == true`) 홈 화면 **최상단에 빨간 배너**가 표시됩니다.  
기존 기상 알람 카드의 해제 버튼은 플랜 카드 표시 조건(`!fallbackUsed`)에 종속되어 있어  
플랜이 없거나 fallback인 경우 버튼이 숨겨질 수 있습니다.  
배너는 이 조건과 독립적으로 항상 표시됩니다.

### 패키지 의존성

```yaml
flutter_local_notifications: ^18.0.0  # OS 알림 예약
timezone: ^0.9.4                       # 한국 시간(Asia/Seoul) 기반 정확한 예약
audioplayers: ^6.1.0                   # 무음 오디오 (백그라운드 유지용)
```

### 테스트 방법

`home_screen.dart`의 `_scheduleAlarmIfNeeded()`를 임시로 수정해 빠르게 테스트:

```dart
// 테스트용 — 1분 뒤 알람 (테스트 후 반드시 원복)
void _scheduleAlarmIfNeeded() {
  AlarmService.instance.scheduleAlarm(
    DateTime.now().add(const Duration(minutes: 1)),
  );
}
```

1. 위 코드로 임시 수정 후 `flutter run`
2. 홈 화면 진입 → 알람 자동 예약
3. 홈 버튼으로 백그라운드 전환 (또는 그대로 대기)
4. 1분 후 알람음 + 빨간 배너 확인
5. "알람 해제" 버튼으로 해제
6. 테스트 후 원래 코드로 복원
