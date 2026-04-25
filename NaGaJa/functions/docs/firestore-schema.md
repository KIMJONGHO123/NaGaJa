# Firestore 데이터 모델 (NaGaJa)

NoSQL(문서 DB)이므로 **클라/Functions에서 쓰는 쿼리**에 맞춰 `서브컬렉션 위치`와 **복합 인덱스**를 같이 잡는 것이 중요합니다.

## 경로(큰 틀)

```
users/{userId}                              ← 사용자 루트(doc)
  ├── (필드) 프로필, Wi‑Fi, 준비/이동 기본값
  │
  ├── schedules/{scheduleId}                  ← 반복 수업(템플릿) (subcollection)
  └── dailyPlans/{dailyPlanId}                 ← 날짜별 실행 계획 (subcollection)
        └── scheduleId 로 어떤 schedules 문서에서 왔는지 연결
```

- **`userId`**: Firebase Auth `uid`와 동일하게 두는 것을 권장(규칙/조회 일관).
- **`dailyPlanId`**: 자동 ID(`auto-id`) 권장. 쿼리는 `planDate` + `scheduleId` 등 필드로 수행.
- **타임스탬프**: 앱/Functions에서는 일관되게 **`Timestamp`**(또는 `FieldValue.serverTimestamp()`) 권장. (예시 JSON의 ISO 문자열도 저장 가능하나, 범위 쿼리·정렬은 `Timestamp`가 유리)

---

## 1. `users/{userId}`

| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | `string` | 표시 이름 |
| `email` | `string` | 이메일 (Auth과 중복이면 `email`은 읽기 전용/동기화 정책 정하기) |
| `prepMinutes` | `int` | 개인 준비 시간(분) |
| `defaultTravelMinutes` | `int` | 기본 이동(분), fallback |
| `homeWifiSsids` | `array<string>` | 집 Wi‑Fi SSID (출발 감지) |
| `schoolWifiSsids` | `array<string>` | 학교 Wi‑Fi SSID (도착 감지) |
| `createdAt` | `Timestamp` | 생성 |
| `updatedAt` | `Timestamp` | 수정 |

---

## 2. `users/{userId}/schedules/{scheduleId}`

| 필드 | 타입 | 설명 |
|------|------|------|
| `title` | `string` | 수업명 |
| `dayOfWeek` | `int` | 1=월 … 7=일(팀에서 규칙 고정) |
| `classTime` | `string` | `HH:mm` (수업 시작) |
| `targetArrivalTime` | `string` | `HH:mm` (목표 도착) |
| `startPlaceName` | `string` | 출발지 라벨 |
| `startAddress` | `string` | 출발지 주소(지도 API) |
| `destinationName` | `string` | 도착지 라벨 |
| `destinationAddress` | `string` | 도착지 주소 |
| `transportMode` | `string` | `BUS` \| `WALK` \| `SUBWAY` \| … (앱/Functions에서 enum 통일) |
| `isActive` | `bool` | 사용 여부 |
| `createdAt` | `Timestamp` | 생성 |
| `updatedAt` | `Timestamp` | 수정 |

**인덱스 후보(자주 쓰는 쿼리에 따라):**  
`isActive` + `dayOfWeek` 정렬, 등 — 실제 `where`/`orderBy` 정해지면 `firestore.indexes.json`에 반영.

---

## 3. `users/{userId}/dailyPlans/{dailyPlanId}`

`scheduleId`는 **`users/{userId}/schedules/{id}`** 를 가리키는 **참조 문자열**(또는 `DocumentReference` 저장도 가능, 클라/규칙에 맞게 통일).

| 필드 | 타입 | 설명 |
|------|------|------|
| `scheduleId` | `string` | 소스 `schedules` 문서 id |
| `planDate` | `string` | `YYYY-MM-DD` (캘린더 키로 쓸 때 string이 편함) 또는 `Timestamp` 날짜만(자정) |
| `title` | `string` | 수업명(복사) |
| `dayOfWeek` | `int` | 요일 |
| `classTime` | `string` | `HH:mm` |
| `targetArrivalTime` | `string` | `HH:mm` |
| `startPlaceName` | `string` | |
| `destinationName` | `string` | |
| `transportMode` | `string` | |
| `defaultTravelMinutes` | `int` | 스냅샷(당일) |
| `prepMinutes` | `int` | 스냅샷 |
| `baseDepartureTime` | `Timestamp` | 초기 출발(ISO 문자열 대체 가능) |
| `baseAlarmTime` | `Timestamp` | 초기 알림 |
| `calculationTime` | `Timestamp` | Cloud Functions 실행 시각 |
| `weatherType` | `string` | `RAIN` \| `SNOW` \| `CLEAR` \| … |
| `weatherAdjustMinutes` | `int` | 날씨 가산(분) |
| `weatherCheckedAt` | `Timestamp` | |
| `mapBaseTravelMinutes` | `int` | 지도 API 기준 |
| `congestionAdjustMinutes` | `int` | 혼잡 가산 |
| `predictedTravelMinutes` | `int` | 최종 예상 이동 |
| `finalDepartureTime` | `Timestamp` | 최종 출발 |
| `finalAlarmTime` | `Timestamp` | 최종 알림 |
| `weatherApplied` | `bool` | |
| `congestionApplied` | `bool` | |
| `fallbackUsed` | `bool` | API 실패 시 기본값 |
| `planStatus` | `string` | `CALCULATED` \| `FAILED` \| … |
| `remainingMarginMinutes` | `int` | |
| `displayColor` | `string` | `GREEN` \| `YELLOW` \| `RED` |
| `displayCheckedAt` | `Timestamp` | |
| `alarmDismissedAt` | `Timestamp`? | 없으면 null/필드 생략 |
| `departedAt` | `Timestamp`? | |
| `arrivedAt` | `Timestamp`? | |
| `actualTravelMinutes` | `int`? | 계산/기록 후 |
| `resultStatus` | `string` | `ON_TIME` \| `LATE` \| … |
| `createdAt` | `Timestamp` | |
| `updatedAt` | `Timestamp` | |

**대표 쿼리(예시) → 인덱스가 필요할 수 있음**

- 특정 달: `where planDate >= "2026-04-01" and planDate <= "2026-04-30"` + `orderBy planDate`
- 오늘 일정: `where planDate == "2026-04-15"`
- 스케줄별: `where scheduleId == "..."` + `orderBy planDate`

`planDate`를 `string`으로 두면 **사전식 정렬**이 `YYYY-MM-DD` 형식에서 날짜순으로 맞습니다.

---

## 설계 시 메모

1. **스냅샷 필드** (`defaultTravelMinutes`, `prepMinutes` 등)는 `users`/`schedules`가 나중에 바뀌어도 **과거 plan 재현**에 유리.
2. **Wi‑Fi SSID**는 민감할 수 있으므로 **보안 규칙**에서 `users` 쓰기는 본인만, 읽기 최소화.
3. **Cloud Functions**는 `userId`·`planId`를 경로/트리거로 받아 **서버에서도 동일한 경로 규칙**을 쓰면 실수가 줄어듦.

## 다음 작업(프로젝트에 이어서 하면 됨)

- `firestore.rules`: `request.auth.uid == userId` 로 `users/{userId}/**` 제한
- `firestore.indexes.json`: 위 쿼리 확정 후 복합 인덱스 추가
- (선택) `dailyPlans`를 `schedules` 아래에 두는 방식: `users/{userId}/schedules/{sid}/dailyPlans/{pid}`  
  - 장점: “한 수업에 속한 일자별 plan” 쿼리가 자연스러움  
  - 지금 제안: **사용자 기준 “전체 캘린더” 조회**가 쉬운 **플랫 구조** (`users/.../dailyPlans`)를 기본으로 함

이 문서는 **큰 틀/경로/필드** 기준이며, `dayOfWeek` 0/1 시작 등 팀 합의만 맞추면 됩니다.
