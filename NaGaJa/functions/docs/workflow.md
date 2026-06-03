# Daily Plan Workflow

## 기준 문서

- 계산 기준 문서는 `functions/docs/alarm-calculation-logic.md.md`이다.
- 요청에서는 `functions/docs/alarm-calculation-logic.md`로 불릴 수 있다.
- 이 문서는 계산 흐름을 설명한다.
- 계산 기준 자체는 기준 문서를 따른다.
- 기준 문서를 새로 만들지 않는다.

## 진입점

- HTTP Function 진입점은 `generateDailyPlan`이다.
- 위치는 `src/index.ts`이다.
- `generateDailyPlan`은 `runFullDailyPlanPipeline`을 호출한다.

입력값:

- `userId`: 필수.
- `scheduleId`: 선택. 있으면 단일 schedule만 계산한다.
- `planDate`: 선택. 없으면 KST 기준 오늘 날짜를 사용한다.

## 파이프라인 흐름

- `runFullDailyPlanPipeline`은 `src/services/dailyPlanPipeline.ts`에 있다.
- 먼저 `planDate`를 결정한다.
- `PipelineTracer`를 생성한다.
- `scheduleId`가 있으면 `calculateAndUpsertDailyPlan`을 한 번 실행한다.
- `scheduleId`가 없으면 해당 요일의 active schedules를 모두 계산한다.
- 결과와 `summary`를 반환한다.

파이프라인 단계 이름:

- `load_user`
- `load_schedule`
- `geocoding`
- `schedule_update_coords`
- `weather_api`
- `transit_api`
- `congestion_api`
- `route_select`
- `firestore_upsert`

## 단일 schedule 계산 흐름

- 핵심 함수는 `calculateAndUpsertDailyPlan`이다.
- 위치는 `src/services/dailyPlanCalculator.ts`이다.

계산 순서:

1. `users/{userId}`를 읽는다.
2. `users/{userId}/schedules/{scheduleId}`를 읽는다.
3. 초기 시간을 계산한다.
4. 좌표가 없으면 주소를 geocoding한다.
5. 좌표와 grid 값을 schedule에 저장한다.
6. 날씨 API를 호출한다.
7. TMAP transit API를 호출한다.
8. 경로별 후보를 계산한다.
9. 최적 경로를 선택한다.
10. 최종 출발 시각과 최종 알람 시각을 계산한다.
11. `dailyPlans`에 upsert한다.

## 초기 시간 계산

- 시간 계산 함수는 `calculateInitialPlanTimes`이다.
- 위치는 `src/utils/planTime.utils.ts`이다.

계산식:

```text
baseDepartureTime = targetArrivalTime - defaultTravelMinutes
baseAlarmTime = baseDepartureTime - prepMinutes
calculationTime = baseAlarmTime - 30 minutes
```

- 30분 값은 `API_CALCULATION_LEAD_MINUTES`이다.

## 외부 API 계산 흐름

- TMAP API는 `initialTimes.calculationAt` 기준으로 호출한다.
- TMAP API가 여러 경로를 반환하면 모든 경로를 계산한다.
- 각 경로의 `totalTime`을 분 단위로 변환한다.
- 각 경로의 `estimatedDepartureAt`을 계산한다.

계산식:

```text
estimatedDepartureAt = targetArrivalAt - mapBaseTravelMinutes
```

- 혼잡도는 `estimatedDepartureAt` 기준으로 계산한다.
- 날씨는 `estimatedDepartureAt`을 `fcstTime`으로 변환해 선택한다.
- 현재 시각 기준으로 혼잡도와 날씨를 계산하지 않는다.

## 최종 경로 선택

경로 후보는 다음 순서로 정렬한다.

1. 낮은 `predictedTravelMinutes`
2. 낮은 `congestionAdjustMinutes`
3. 낮은 지도 API 원본 itinerary index

선택된 경로는 다음 필드에 반영된다.

- `mapBaseTravelMinutes`
- `congestionAdjustMinutes`
- `weatherAdjustMinutes`
- `predictedTravelMinutes`

## 최종 알람 계산

- 최종 시간 계산 함수는 `calculateFinalPlanTimes`이다.

계산식:

```text
predictedTravelMinutes = mapBaseTravelMinutes + congestionAdjustMinutes + weatherAdjustMinutes
finalDepartureTime = targetArrivalTime - predictedTravelMinutes
finalAlarmTime = finalDepartureTime - prepMinutes
```

## 표시 색상 계산

- 여유 시간 계산 함수는 `calculateRemainingMarginMinutes`이다.
- 표시 색상 함수는 `toDisplayColor`이다.

계산식:

```text
remainingMarginMinutes = (targetArrivalTime - displayCheckedAt) - predictedTravelMinutes
```

현재 코드 기준:

- `GREEN`: `remainingMarginMinutes > 15`
- `YELLOW`: `remainingMarginMinutes >= 0`
- `RED`: `remainingMarginMinutes < 0`

## fallback 규칙

- fallback 알람은 반드시 유지한다.
- 외부 API 실패 시에도 기본 알람을 유지한다.
- 경로 후보가 없으면 `defaultTravelMinutes`를 기준으로 계산한다.
- 실패 여부는 `fallbackUsed`에 반영한다.

## 주의할 점

- `weatherCheckedAt`의 의미는 코드와 문서에서 함께 확인한다.
- `baseTime`과 `fcstTime`을 혼동하지 않는다.
- 기준 문서 파일명은 현재 `alarm-calculation-logic.md.md`이다.
- 기준 문서는 터미널에서 한글 인코딩이 깨져 보일 수 있다.
