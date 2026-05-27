# NaGaJa Agent Guide

## 기본 작업 범위

- 기본 작업 범위는 `functions/src`이다.
- 백엔드 작업은 `functions` 기준으로 판단한다.
- Flutter 앱 파일은 요청이 있을 때만 수정한다.
- 루트 설정 파일은 영향 범위를 먼저 확인한다.

## 수정 금지 범위

- `functions/lib`는 빌드 산출물이다.
- `functions/lib`는 직접 수정하지 않는다.
- `build`, `.dart_tool`, 플랫폼별 빌드 폴더는 직접 수정하지 않는다.
- `.env` 값은 읽거나 출력하지 않는다.
- secret 값은 문서에 쓰지 않는다.

## 백엔드 기준 경로

- Firebase Functions source: `functions/src`
- Functions entry point: `functions/src/index.ts`
- Daily plan pipeline: `functions/src/services/dailyPlanPipeline.ts`
- Daily plan calculator: `functions/src/services/dailyPlanCalculator.ts`
- Time utils: `functions/src/utils/planTime.utils.ts`
- External API modules: `functions/src/weather`
- Backend docs: `functions/docs`

## 계산 기준 문서

- 알람 계산 기준 문서는 계산 로직의 기준이다.
- 현재 checkout의 실제 파일명은 `functions/docs/alarm-calculation-logic.md.md`이다.
- 요청에서는 `functions/docs/alarm-calculation-logic.md`로 불릴 수 있다.
- 계산 로직을 바꾸기 전에 실제 파일 경로를 확인한다.
- 기준 문서의 계산 흐름을 임의로 바꾸지 않는다.

## 반드시 지킬 규칙

- fallback 알람 로직은 제거하지 않는다.
- 외부 API 실패 시에도 기본 알람은 유지한다.
- Firestore 필드명은 임의로 변경하지 않는다.
- `baseTime`과 `fcstTime`을 혼동하지 않는다.
- 혼잡도와 날씨는 현재 시각이 아니라 경로별 출발 예상 시각 기준으로 계산한다.
- 지도 API가 여러 경로를 반환하면 경로별로 계산한 뒤 최적 경로를 선택한다.
- 최적 경로 선택 기준은 `predictedTravelMinutes`, `congestionAdjustMinutes`, 지도 API 기본 순서이다.

## 문서 목록

- `functions/AGENT.md`: Functions 전용 작업 규칙.
- `functions/docs/workflow.md`: `dailyPlan` 계산 흐름.
- `functions/docs/firestore-schema.md`: Firestore 구조와 필드 규칙.
- `functions/docs/api-rules.md`: 외부 API 연동 규칙.
- `functions/docs/testing-rules.md`: 테스트와 검증 규칙.
