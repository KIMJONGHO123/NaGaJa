# NaGaJa 프로젝트

## 개요

**나가자(NaGaJa)** — 학생의 시간표, 위치, 교통수단, 준비시간을 기반으로 최적 출발 시각을 자동 계산해주는 등교 지원 앱.
날씨·혼잡도·대중교통 경로를 실시간으로 반영하고, IoT 물리 알람시계(Raspberry Pi)와 연동한다.

## 기술 스택

| 계층 | 기술 |
|------|------|
| 프론트엔드 | Flutter (Dart), iOS/Android |
| 백엔드 | Firebase Cloud Functions (TypeScript) |
| DB | Cloud Firestore |
| 인증 | Firebase Auth (Google Sign-In) |
| 외부 API | TMAP 대중교통, 기상청 단기예보, Kakao Maps 지오코딩 |
| 하드웨어 | Raspberry Pi 4, NeoPixel LED, OLED |
| 배포 리전 | asia-northeast3 (서울) |
| Firebase 프로젝트 | nagaja-a6a8b |

## 프로젝트 구조

```
NaGaJa/
├── lib/                        # Flutter 앱 (Dart)
│   ├── main.dart               # 진입점 + 라우팅
│   ├── models/user_model.dart  # UserModel, ScheduleEntry, DailyPlanModel
│   ├── services/
│   │   ├── auth_service.dart         # Firebase Auth / Google Sign-In
│   │   ├── settings_service.dart     # 시간표·사용자 설정 (ChangeNotifier)
│   │   ├── daily_plan_service.dart   # Cloud Function 호출 + 캐시
│   │   └── kakao_address_service.dart
│   └── views/
│       ├── home/home_screen.dart     # 메인: 시계, 게이지, 준비/출발 버튼
│       ├── calendar/calendar_screen.dart
│       ├── settings/settings_screen.dart
│       ├── late_response/late_response_screen.dart
│       └── onboarding/onboarding_screen.dart
│
├── functions/src/              # Cloud Functions (TypeScript)
│   ├── index.ts                # HTTP 엔드포인트 정의
│   ├── services/
│   │   ├── dailyPlanPipeline.ts    # 파이프라인 오케스트레이션
│   │   ├── dailyPlanCalculator.ts  # 핵심 계산 로직
│   │   └── pipelineTracer.ts       # 파이프라인 단계 추적
│   ├── types/                  # User, Schedule, DailyPlan 인터페이스
│   ├── utils/planTime.utils.ts # 시간 계산 유틸
│   └── weather/                # 외부 API 모듈
│       ├── weather.service.ts      # 기상청 API
│       ├── geocoding.service.ts    # Kakao 지오코딩
│       ├── transit/                # TMAP 대중교통
│       └── congestion/             # CSV 기반 버스 혼잡도
│
├── firestore.rules             # Firestore 보안 규칙
└── firebase.json               # Firebase 설정
```

## Firestore 스키마

```
users/{userId}
  prepMinutes: number           # 준비 시간 (분)
  defaultTravelMinutes: number  # 기본 이동 시간 (분)

users/{userId}/schedules/{scheduleId}
  title: string                 # 과목명
  dayOfWeek: number             # 1=월 ~ 7=일
  classTime: string             # "HH:MM"
  targetArrivalTime: string     # "HH:MM"
  startAddress / destinationAddress: string
  startLat, startLng, startNx, startNy: number  # 출발지 좌표 (캐시됨)
  endLat, endLng: number                         # 목적지 좌표 (캐시됨)
  transportMode: "BUS" | "SUBWAY" | "WALK"
  isActive: boolean

users/{userId}/dailyPlans/{planDate_scheduleId}
  finalDepartureTime: Timestamp # 최종 출발 시각
  finalAlarmTime: Timestamp     # 최종 알람 시각
  predictedTravelMinutes: number
  mapBaseTravelMinutes: number
  weatherAdjustMinutes: number
  congestionAdjustMinutes: number
  selectedRouteNo: string | null  # 선택된 버스 노선번호 (버스 외 노선은 null)
  weatherType: "CLEAR" | "RAIN" | "SNOW"
  weatherApplied: boolean
  congestionApplied: boolean
  displayColor: "GREEN" | "YELLOW" | "RED"
  remainingMarginMinutes: number
  fallbackUsed: boolean
  planStatus: "CALCULATED" | "FAILED"
  # 사용자 행동 기록 (현재 버튼 수동 저장, 설계 의도는 Wi-Fi 자동 감지)
  departedAt?: Timestamp        # 출발 시각
  arrivedAt?: Timestamp         # 도착 시각
  actualTravelMinutes?: number  # 실제 이동시간 (departedAt ~ arrivedAt)
  resultStatus?: "ON_TIME" | "LATE"  # 결과 상태 (미구현)
  alarmDismissedAt?: Timestamp  # 알람 해제 시각 (미구현)
```

## 핵심 시간 계산 공식

```
calculationAt      = targetArrivalTime - defaultTravelMinutes - prepMinutes - 30분
baseDepartureAt    = targetArrivalTime - defaultTravelMinutes
baseAlarmAt        = baseDepartureAt - prepMinutes

predictedTravelMinutes = mapBaseTravelMinutes + congestionAdjustMinutes + weatherAdjustMinutes
finalDepartureAt   = targetArrivalTime - predictedTravelMinutes
finalAlarmAt       = finalDepartureAt - prepMinutes

remainingMarginMinutes = (targetArrivalAt - now) - predictedTravelMinutes
displayColor:
  GREEN  → remainingMarginMinutes > 15
  YELLOW → remainingMarginMinutes >= 0
  RED    → remainingMarginMinutes < 0
```

## Cloud Functions 엔드포인트

| 함수명 | 역할 |
|--------|------|
| `generateDailyPlan` | **핵심** — 일일 계획 계산 및 Firestore 저장 |
| `getTransitData` | TMAP 대중교통 경로 조회 |
| `getCongestionData` | 버스 혼잡도 계산 |
| `getWeatherData` | 날씨 조회 |
| `createUser` | 테스트용 mock 유저 생성 |
| `createSchedule` | 테스트용 mock 스케줄 생성 |
| `createDailyPlansAtDawn` | **scheduled** — 새벽에 당일 dailyPlan 일괄 생성 (배포됨, 코드 미포함) |
| `calculatePendingDailyPlans` | **scheduled** — 미계산 dailyPlan 재처리 (배포됨, 코드 미포함) |

## generateDailyPlan 파이프라인 흐름

```
HTTP 요청 (userId, planDate?, scheduleId?)
  → runFullDailyPlanPipeline
  → calculateAndUpsertDailyPlan (스케줄별 반복)
      1. 유저 / 스케줄 로드
      2. 좌표 없으면 Kakao 지오코딩 후 스케줄에 저장 (캐시)
      3. 기상청 API로 날씨 조회
      4. TMAP API로 경로 후보 최대 10개 조회
      5. 경로별: 혼잡도(버스만) + 날씨 보정 계산
      6. 최적 경로(predictedTravelMinutes 최소) 선택
      7. finalDepartureTime / finalAlarmTime 산출
      8. Firestore dailyPlans에 upsert
  → 결과 반환
```

## 외부 API 동작 방식

- **TMAP 대중교통**: `searchDttm` 파라미터로 미래 시간 기준 경로 조회, 버스/지하철/복합 경로 반환
- **기상청 단기예보**: WGS84 → grid 좌표 변환 후 조회, 강수형태(PTY)·강수량(PCP)·적설(SNO) 기준으로 이동시간 보정
- **Kakao 지오코딩**: 주소 → 위도/경도 변환, 스케줄에 캐시되어 재호출 방지
- **혼잡도**: 부산 버스 노선 CSV 데이터 내장, 시간대 슬롯 기준 보정값 산출

## Flutter 앱 상태 관리

- `SettingsService` (ChangeNotifier): 사용자 프로필, 시간표 Firestore 동기화
- `DailyPlanService`: Cloud Function 호출 결과 캐시, 폴백 로컬 계산
- `IndexedStack`으로 탭 전환 시 상태 유지
- 홈 화면: 1초 Timer로 실시간 시계/카운트다운 갱신

## 완료 / 미완성 기능

**완료**
- 핵심 시간 계산 엔진 (날씨 + 혼잡도 + TMAP)
- 전체 UI (홈, 캘린더, 설정, 지각대응, 온보딩)
- Firebase Auth, Firestore 연동
- 홈 화면 정보 카드화: **기상 알람(`finalAlarmTime`) / 날씨 보정 / 혼잡도 보정** 카드 + 노선번호(새로고침 행) 표시 (`fallbackUsed: false`일 때만)
- "출발" / "도착 확인" 버튼 → `dailyPlan.departedAt` / `arrivedAt` / `actualTravelMinutes` 저장
- 도착 확인 후 **"도착 완료" 비활성** 처리 (중복 `arrivalLogs`/`arrivedAt` 차단)
- 앱 재시작 시 `_departed` / `_arrived` 상태 Firestore에서 복원
- **준비 타이머 영속화**: 시작 시각 SharedPreferences 저장 → 재시작 복원, 출발 시 종료
- 로컬 폴백 dailyPlan을 `{planDate}_{scheduleId}` **고정 ID**로 생성(백엔드 규칙 일치, 중복 방지)
- 출발/도착 업데이트를 **로드된 실제 `dailyPlanId`** 로 수행 (레거시 랜덤 ID/백엔드 ID 모두 대응)
- **`resultStatus`(ON_TIME/LATE)** 도착 시 계산·저장 (`arrivedAt` vs **`classTime`(수업 시작 시각)** — 수업 시작 후 도착 = 지각)
- **캘린더 Firestore 실연동**: `dailyPlans` 기반 정시/지각/결석 집계 (Mock 제거, 새로고침 버튼)
- `arrivalLogs` 보안 규칙 추가 및 배포 완료
- **격자(nx/ny) 변환 일원화**: Flutter `_toKmaGrid` 제거 → 좌표만 전송, 백엔드 `grid.utils.convertToGrid`가 격자 계산 (회의 결정 반영)
- **온보딩 도로명주소 검색**: 설정의 Kakao 주소검색 위젯을 [address_search_field.dart](lib/views/widgets/address_search_field.dart) 공용 위젯으로 추출 → 온보딩(기초정보 입력)에서도 사용. 온보딩 단계부터 좌표 저장 → geocoding 500 차단
- **Wi-Fi 자동 출결 1·2단계**: 설정 "Wi-Fi 출결" 카드(집/학교 SSID 등록) + [wifi_attendance_service.dart](lib/services/wifi_attendance_service.dart)(연결 변화 감지 → 출발/도착 자동 기록, 디바운스·시간창·멱등성·날짜리셋·재진입가드). 에뮬+실기기(S23+) 발화 검증
- **Wi-Fi 자동 출결 3-a (백그라운드)**: `ACCESS_BACKGROUND_LOCATION` 권한 + 재경의 포그라운드 서비스(프로세스 생존)로 **앱 내려도 SSID 읽어 자동 출결**. 재경 네이티브 수정 없이 동작. **실기기(S23+) 백그라운드 출발/도착 발화 검증 완료** (단 1기기 기준). 완전종료(3-b)는 네이티브 필요
- **백엔드 실패 시 로컬 폴백 보강**: `generateDailyPlan` 500이어도 해당 scheduleId 플랜이 없으면 로컬 폴백 생성(`_plans.isEmpty`→`!containsKey`) → 백엔드 장애 시에도 앱/감지 동작

**미완성 (Flutter)**
- 캘린더 자동 새로고침: `IndexedStack`으로 시작 시 1회 로드 → 도착 직후 반영은 새로고침 버튼 필요 (탭 포커스 시 자동 reload 개선 여지)
- **기상 알람 실제 동작**: 현재 홈 카드는 `finalAlarmTime` **표시만** 함(알람 안 울림). `flutter_local_notifications`로 `finalAlarmTime`에 로컬 알림 예약 시 백엔드 없이 구현 가능 (권한·정확알람 `SCHEDULE_EXACT_ALARM` 필요). 서버 푸시가 필요하면 FCM(백엔드)로. → **나중에 진행 예정**

**미완성 (백엔드·협의 필요)**
- FCM 푸시 알림 (`finalAlarmTime` 기준)
- Wi-Fi 자동 감지 **3-b (완전 종료)**: 앱 스와이프/OS kill 시 Dart가 죽으므로 네이티브(Kotlin) BroadcastReceiver 필요. (1·2 + 3-a 백그라운드는 Flutter 완료·실기기 검증, 3-b만 남음)
- `alarmDismissedAt` 저장
- Raspberry Pi BLE 연동

## Firestore 인덱스

배포된 복합 인덱스 (현재 1개):

| 컬렉션 | 필드 | 용도 |
|--------|------|------|
| `dailyPlans` | `planStatus` (ASC) + `calculationTime` (ASC) | 미계산 플랜 조회 |

## 팀 브랜치 구조

| 브랜치 | 역할 |
|--------|------|
| `main` | 배포 브랜치 |
| `dev` | 공용 통합 브랜치 (팀원 간 공유) |
| `kim` | 김종호 작업 브랜치 (백엔드 담당) |
| `dev_woosuk` | 우석 작업 브랜치 |

## Flutter ↔ 백엔드 연계 현황

### 구현 완료
| 필드 | 상태 |
|------|------|
| `finalAlarmTime` | 홈 화면 **기상 알람 카드**로 시각 표시 (FCM 발송은 없음) |
| `weatherType` / `weatherAdjustMinutes` | 홈 화면 **날씨 카드** (맑음/비/눈 + `+N분`) |
| `congestionAdjustMinutes` | 홈 화면 **혼잡도 보정 카드** (`+N분`) |
| `selectedRouteNo` | 홈 화면 새로고침 행에 `N번 기준` 표시 |
| `fallbackUsed` | `false`일 때만 카드 표시, `true`면 "실시간 경로 계산하기" 표시 |
| `departedAt` / `arrivedAt` | 출발/도착 버튼 저장, 앱 재시작 시 `_departed`/`_arrived` 복원, 도착 후 버튼 비활성 |
| `actualTravelMinutes` | 도착 확인 시 `arrivedAt - departedAt` 자동 계산 저장 |
| `resultStatus` | 도착 시 `arrivedAt` vs **`classTime`** 비교로 ON_TIME/LATE 저장, 캘린더 집계 |

### 출결 판정 기준
- **정시(ON_TIME)**: 도착 버튼 누른 시각(`arrivedAt`)이 **수업 시작 시각(`classTime`) 이하** (예: 9:00 수업 → 9:00:00까지 도착)
- **지각(LATE)**: `arrivedAt`이 `classTime` 초과 (예: 9:00 수업 → 9:00 이후 도착)
- **결석(ABSENT)**: 지난 날짜에 수업(플랜)이 있었으나 도착 기록(`arrivedAt`)이 없음 (추론)
- 하루 여러 수업: 나쁜 상태 우선 (지각 > 결석 > 정시)
- 기준 시각은 `targetArrivalTime`(=수업-5분, 출발시각 계산용)이 **아니라** `classTime`임에 유의

### 미구현 (Flutter)
| 필드 | 상태 |
|------|------|
| `finalAlarmTime` | 홈 기상 알람 카드로 **표시만** (실제 알람 미발생) — 로컬 알림/FCM 미구현, 나중에 진행 |
| `alarmDismissedAt` | 미구현 |
| Wi-Fi 자동 감지 | **1·2단계 + 3-a(백그라운드) 완료** — SSID 등록 + 자동 출발·도착, 앱 내려도 동작(ACCESS_BACKGROUND_LOCATION). 에뮬+실기기(S23+) 검증. 3-b(완전종료)만 네이티브 남음 |

### 설계 의도 vs 현재 구현
- `departedAt` / `arrivedAt`: Wi-Fi 자동 감지(1·2 + 3-a 백그라운드) + 버튼 수동 저장(폴백) 병행. 완전종료(3-b)만 네이티브 추후
- 아침 자동 실행(`createDailyPlansAtDawn`): 스케줄러 배포됨, Flutter는 수동 트리거 병행

### `generateDailyPlan` 500 / 칩(카드) 미표시 트러블슈팅 (2026-06-01 확인)
- **증상**: `generateDailyPlan`이 500(`주소 검색 결과 없음`) → Flutter는 로컬 폴백(`fallbackUsed:true`)으로 대체 → 카드 미표시.
- **원인**: 스케줄에 좌표 캐시(`startLat` 등)가 없으면 백엔드가 매번 Kakao **주소검색(address.json)** 으로 재지오코딩하는데, 이 호출이 **일시적으로 0건**을 반환할 때가 있음. 주소·키 문제 아님(동일 키로 직접 호출 시 정상 변환됨). 한 번 성공하면 좌표가 캐시되어 이후엔 지오코딩을 건너뛰어 안정적.
- **`fallbackUsed` 판정**: 출발지 격자(`startNx`/`startNy`)가 없으면 날씨 단계에서 `fallbackUsed=true`가 됨([dailyPlanCalculator.ts](functions/src/services/dailyPlanCalculator.ts)). 좌표만 있고 격자가 없으면 경로/혼잡은 나와도 `fallbackUsed:true`라 카드가 숨겨짐.
- **참고**: Flutter는 Kakao **keyword.json**(장소검색)으로 좌표를 이미 받지만 `ScheduleEntry.toMap()`이 좌표를 보내지 않아(커밋 `877e622`) 백엔드가 재지오코딩함.
- **강건화(백엔드, 협의)**: `getAddress`가 0건일 때 재시도 또는 keyword.json 폴백.

## 개발 환경

```bash
# Flutter 앱 실행
flutter run

# Cloud Functions 로컬 에뮬레이터
cd functions && npm run serve

# Functions 배포
firebase deploy --only functions

# Firestore 에뮬레이터 포트: 8080 / Functions: 5001 / Auth: 9099
```

## 환경 변수 (functions/.env)

- `WEATHER_SERVICE_KEY` — 기상청 API 인증키
- `TMAP_APP_KEY` — TMAP API 키 (transit.config.ts)
- `KAKAO_REST_API_KEY` — Kakao REST API 키
