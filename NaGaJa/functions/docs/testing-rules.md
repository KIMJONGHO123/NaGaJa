# Testing Rules

## 기본 규칙

- 문서만 수정한 경우 빌드하지 않는다.
- 코드 수정 없이 `functions/lib`를 생성하지 않는다.
- secret 값은 출력하지 않는다.
- 테스트 결과를 말할 때는 실제 실행 결과를 기준으로 한다.

## package.json scripts

위치:

```text
functions/package.json
```

scripts:

- `npm run lint`: `.js`, `.ts` 파일 ESLint 실행.
- `npm run build`: TypeScript를 `functions/lib`로 컴파일.
- `npm run build:watch`: TypeScript watch build 실행.
- `npm run serve`: build 후 Functions, Firestore emulator 실행.
- `npm run shell`: build 후 Firebase Functions shell 실행.
- `npm run start`: `npm run shell` alias.
- `npm run deploy`: Functions 배포.
- `npm run logs`: Functions log 조회.
- `npm run test:pipeline`: build 후 Firestore emulator에서 pipeline 테스트 실행.

## 문서 변경 검증

문서만 바꾼 경우 파일 존재 확인을 우선한다.

```powershell
Get-ChildItem functions\docs
```

코드 빌드는 실행하지 않는다.

## TypeScript 검증

코드를 수정한 경우 우선 `--noEmit` 검증을 사용한다.

```powershell
cd functions
.\node_modules\.bin\tsc.cmd --noEmit
```

이 명령은 `functions/lib`를 생성하지 않는다.

## 빌드 검증

빌드 산출물이 필요한 경우에만 실행한다.

```powershell
cd functions
npm run build
```

주의:

- `npm run build`는 `functions/lib`를 생성한다.
- `functions/lib`는 직접 수정하지 않는다.
- `functions/lib` 변경은 TypeScript compiler 결과여야 한다.

## Emulator 테스트

주요 통합 테스트:

```powershell
cd functions
npm run test:pipeline
```

실제 실행 내용:

```text
npm run build && npx firebase emulators:exec --only firestore "node scripts/test-fullDailyPlanPipeline.mjs"
```

주의:

- 이 테스트는 `functions/lib`를 import한다.
- 먼저 build가 필요하다.
- Firestore emulator가 필요하다.

## 테스트 전제 조건

pipeline 테스트에는 다음 조건이 필요할 수 있다.

- Firestore emulator
- `WEATHER_SERVICE_KEY`
- `KAKAO_REST_API_KEY`
- `TMAP_APP_KEY`
- congestion CSV data

출력 규칙:

- key 존재 여부는 boolean으로만 표시한다.
- secret 값은 출력하지 않는다.

## Pipeline 검증 기준

`test-fullDailyPlanPipeline.mjs`는 `assertPipelineSteps`를 사용한다.

기본 기대 단계:

- `load_user`
- `load_schedule`
- `weather_api`
- `firestore_upsert`

상황에 따라 기대되는 단계:

- `geocoding`
- `transit_api`
- `congestion_api`
- `route_select`

exit code 의미:

- `0`: 성공.
- `1`: 실패.
- `2`: 일부 외부 검증 skip 또는 부분 성공.

## 알려진 주의사항

- `scripts/test-getTransitData.mjs`는 `../lib/weather/transit/transit.config.js`에서 `TMAP_APP_KEY`를 import한다.
- 현재 `src/weather/transit/transit.config.ts`는 `TMAP_APP_KEY`를 export하지 않는다.
- 이 스크립트는 자동 검증 기준으로 쓰기 전에 먼저 점검한다.

## 문서 전용 작업 규칙

- 문서 작업에서는 코드 검증을 강제하지 않는다.
- 문서 파일 존재와 변경 대상만 확인한다.
- 코드 파일이 변경되었는지 확인한다.
