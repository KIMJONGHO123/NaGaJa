# Functions Agent Guide

## 작업 원칙

- 기본 작업 위치는 `functions/src`이다.
- `functions/lib`는 직접 수정하지 않는다.
- `.env` 값은 읽거나 출력하지 않는다.
- `.env.example`은 변수명 확인용으로만 본다.
- 문서는 한글로 작성한다.
- 함수명, 변수명, 필드명, 타입명, 파일 경로, 명령어는 원문을 유지한다.

## 핵심 파일

- `src/index.ts`: HTTP Functions 진입점과 Firebase 초기화.
- `src/services/dailyPlanPipeline.ts`: `dailyPlan` 파이프라인 실행.
- `src/services/dailyPlanCalculator.ts`: `dailyPlan` 계산과 Firestore upsert.
- `src/services/pipelineTracer.ts`: 파이프라인 단계 기록.
- `src/utils/planTime.utils.ts`: 시간 계산과 표시 색상 계산.
- `src/weather/geocoding.service.ts`: Kakao 주소 검색.
- `src/weather/weather.service.ts`: 기상청 API 호출.
- `src/weather/weather.filter.ts`: `fcstDate`, `fcstTime` 기준 예보 선택.
- `src/weather/weather.mapper.ts`: `PTY`, `PCP`, `SNO` 기반 날씨 보정.
- `src/weather/transit`: TMAP 대중교통 경로 요청과 파싱.
- `src/weather/congestion`: 버스 혼잡도 CSV 파싱과 보정.

## dailyPlan 작업 규칙

- `dailyPlans`는 하루 단위 계산 결과 스냅샷이다.
- `generateDailyPlan`은 `runFullDailyPlanPipeline`을 호출한다.
- `runFullDailyPlanPipeline`은 단일 schedule 또는 해당 요일의 active schedules를 계산한다.
- `calculateAndUpsertDailyPlan`은 계산 결과를 `dailyPlans`에 저장한다.
- fallback 알람 로직은 제거하지 않는다.
- 외부 API 실패가 기본 알람 삭제로 이어지면 안 된다.

## Firestore 작업 규칙

- 주요 경로는 `users/{userId}`이다.
- schedule 경로는 `users/{userId}/schedules/{scheduleId}`이다.
- daily plan 경로는 `users/{userId}/dailyPlans/{dailyPlanId}`이다.
- Firestore 필드명은 임의로 변경하지 않는다.
- 필드 변경 전 `src/types`와 `src/services`를 함께 확인한다.
- Flutter 소비자 변경은 사용자가 요청한 경우에만 확인하고 수정한다.

## 외부 API 작업 규칙

- `baseTime`은 기상청 예보 발표 시각이다.
- `fcstTime`은 응답에서 선택할 예보 대상 시각이다.
- `baseTime`과 `fcstTime`을 혼동하지 않는다.
- 혼잡도는 경로별 출발 예상 시각 기준으로 계산한다.
- 날씨는 경로별 출발 예상 시각을 `fcstTime`으로 변환해 선택한다.
- 지도 API가 여러 경로를 반환하면 모든 경로를 먼저 계산한다.
- 최적 경로 선택 기준은 `predictedTravelMinutes`, `congestionAdjustMinutes`, 지도 API 기본 순서이다.

## 테스트 규칙

- 문서만 수정한 경우 빌드하지 않는다.
- 코드 변경 검증은 `.\node_modules\.bin\tsc.cmd --noEmit`을 우선 사용한다.
- `npm run build`는 `functions/lib`를 생성한다.
- `npm run test:pipeline`은 emulator와 빌드 산출물이 필요하다.
- secret 값은 테스트 출력에 노출하지 않는다.
