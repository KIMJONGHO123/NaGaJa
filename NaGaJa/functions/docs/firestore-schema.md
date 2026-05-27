# Firestore Schema

## 기본 규칙

- Firestore 필드명은 임의로 변경하지 않는다.
- 필드 변경 전 `src/types`를 확인한다.
- 필드 변경 전 `src/services`의 read/write를 확인한다.
- Flutter 소비자 수정은 요청이 있을 때만 한다.
- `dailyPlans`는 하루 단위 계산 결과 스냅샷이다.

## 컬렉션 구조

```text
users/{userId}
users/{userId}/schedules/{scheduleId}
users/{userId}/dailyPlans/{dailyPlanId}
```

## users/{userId}

타입 정의 위치:

```text
src/types/user.ts
```

필드:

- `name`
- `email`
- `prepMinutes`
- `defaultTravelMinutes`
- `homeWifiSsids`
- `schoolWifiSsids`
- `createdAt`
- `updatedAt`

`dailyPlan` 계산에서 사용하는 핵심 필드:

- `prepMinutes`
- `defaultTravelMinutes`

## users/{userId}/schedules/{scheduleId}

타입 정의 위치:

```text
src/types/schedule.ts
```

필드:

- `title`
- `dayOfWeek`
- `classTime`
- `targetArrivalTime`
- `startPlaceName`
- `startAddress`
- `startLat`
- `startLng`
- `startNx`
- `startNy`
- `endLat`
- `endLng`
- `endNx`
- `endNy`
- `destinationName`
- `destinationAddress`
- `transportMode`
- `isActive`
- `createdAt`
- `updatedAt`

좌표 필드 규칙:

- `startLat`, `startLng`, `endLat`, `endLng`는 optional이다.
- 좌표가 없으면 `getAddress`로 주소를 변환한다.
- `convertToGrid`로 `startNx`, `startNy`, `endNx`, `endNy`를 계산한다.
- 계산된 좌표와 grid 값은 schedule 문서에 저장한다.

전체 schedule 계산 쿼리:

- `isActive == true`
- `dayOfWeek == resolved dayOfWeek`

## users/{userId}/dailyPlans/{dailyPlanId}

타입 정의 위치:

```text
src/types/dailyPlan.ts
```

필드:

- `dailyPlanId`
- `scheduleId`
- `planDate`
- `title`
- `dayOfWeek`
- `classTime`
- `targetArrivalTime`
- `startPlaceName`
- `destinationName`
- `transportMode`
- `defaultTravelMinutes`
- `prepMinutes`
- `baseDepartureTime`
- `baseAlarmTime`
- `calculationTime`
- `weatherType`
- `weatherAdjustMinutes`
- `weatherCheckedAt`
- `mapBaseTravelMinutes`
- `congestionAdjustMinutes`
- `predictedTravelMinutes`
- `finalDepartureTime`
- `finalAlarmTime`
- `weatherApplied`
- `congestionApplied`
- `fallbackUsed`
- `planStatus`
- `remainingMarginMinutes`
- `displayColor`
- `displayCheckedAt`
- `alarmDismissedAt`
- `departedAt`
- `arrivedAt`
- `actualTravelMinutes`
- `resultStatus`
- `createdAt`
- `updatedAt`

## dailyPlans upsert 규칙

- 조회 경로는 `users/{userId}/dailyPlans`이다.
- 조회 조건은 `planDate`와 `scheduleId`이다.
- 기존 문서가 없으면 새 문서를 만든다.
- 기존 문서가 있으면 같은 `dailyPlanId`로 덮어쓴다.
- 기존 `createdAt`은 유지한다.
- `updatedAt`은 새 값으로 저장한다.

## 필드 변경 시 주의사항

- `fallbackUsed`는 제거하지 않는다.
- `baseDepartureTime`과 `baseAlarmTime`은 제거하지 않는다.
- `finalDepartureTime`과 `finalAlarmTime`은 계산 결과로 유지한다.
- `dailyPlans`의 snapshot 의미를 바꾸지 않는다.
- 필드명 변경은 migration 계획 없이 진행하지 않는다.
