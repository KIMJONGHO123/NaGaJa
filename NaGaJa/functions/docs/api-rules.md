# External API Rules

## 기본 규칙

- 외부 API 실패는 기본 알람 삭제로 이어지면 안 된다.
- secret 값은 출력하지 않는다.
- `.env`는 읽거나 문서에 쓰지 않는다.
- `.env.example`은 변수명 확인용으로만 본다.
- 계산 기준은 `functions/docs/alarm-calculation-logic.md.md`를 따른다.

## 환경 변수

필요한 변수명:

- `WEATHER_SERVICE_KEY`
- `KAKAO_REST_API_KEY`
- `TMAP_APP_KEY`
- `BUS_CONGESTION_CSV_PATH`

주의:

- `.env.example`의 한글 설명은 깨져 보일 수 있다.
- 변수명은 유지한다.
- 값은 노출하지 않는다.

## Geocoding

파일:

- `src/weather/geocoding.service.ts`

Provider:

- Kakao Local address search API

입력:

- address string

출력:

- `longitude`
- `latitude`

사용 흐름:

1. `startAddress`를 좌표로 변환한다.
2. `destinationAddress`를 좌표로 변환한다.
3. `convertToGrid`로 기상청 grid 값을 계산한다.
4. schedule 문서에 좌표와 grid 값을 저장한다.

## Transit

파일:

- `src/weather/transit/transit.service.ts`
- `src/weather/transit/transit.request.ts`
- `src/weather/transit/transit.parser.ts`

Provider:

- TMAP transit API

요청 필드:

- `startX`: 출발지 longitude
- `startY`: 출발지 latitude
- `endX`: 도착지 longitude
- `endY`: 도착지 latitude
- `format`: `json`
- `count`: 선택
- `searchDttm`: `yyyymmddhhmi`

규칙:

- `searchDttm`은 `formatSearchDttm`으로 만든다.
- `dailyPlan` 계산에서는 `initialTimes.calculationAt`을 사용한다.
- 여러 itinerary가 오면 모두 계산한다.
- 첫 번째 경로를 바로 선택하지 않는다.

## Route Candidate

각 itinerary 계산 순서:

1. `totalTime`을 분 단위로 변환한다.
2. `mapBaseTravelMinutes`를 계산한다.
3. `estimatedDepartureAt`을 계산한다.
4. 버스 경로이면 `busRouteNo`를 추출한다.
5. `estimatedDepartureAt` 기준으로 혼잡도를 계산한다.
6. `estimatedDepartureAt` 기준으로 날씨 `fcstTime`을 선택한다.
7. `predictedTravelMinutes`를 계산한다.

계산식:

```text
estimatedDepartureAt = targetArrivalAt - mapBaseTravelMinutes
predictedTravelMinutes = mapBaseTravelMinutes + congestionAdjustMinutes + weatherAdjustMinutes
```

## Congestion

파일:

- `src/weather/congestion/congestion.service.ts`
- `src/weather/congestion/congestion.paths.ts`
- `src/weather/utils/time-change.utils.ts`

CSV 선택 순서:

1. `BUS_CONGESTION_CSV_PATH`
2. `functions/data/bus-congestion-busan.csv`
3. `functions/data/sample-bus-congestion.csv`

시간 변환 규칙:

- `00`분부터 `14`분까지는 해당 정시이다.
- `15`분부터 `44`분까지는 해당 시각의 30분이다.
- `45`분부터 `59`분까지는 다음 정시이다.

예시:

- `08:05` -> `0800`
- `08:22` -> `0830`
- `08:41` -> `0830`
- `07:58` -> `0800`

혼잡도 계산:

- route number로 CSV row를 필터링한다.
- 변환된 time slot의 승차 건수를 읽는다.
- 값을 내림차순으로 정렬한다.
- 상위 30% 평균을 계산한다.
- 최소 1개 sample은 사용한다.

혼잡도 기준:

- `LOW`: 평균 `0` 이상 `10` 이하, `+0`
- `MEDIUM`: 평균 `10` 초과 `30` 이하, `+3`
- `HIGH`: 평균 `30` 초과, `+7`

## Weather

파일:

- `src/weather/weather.service.ts`
- `src/weather/weather.extract.ts`
- `src/weather/weather.filter.ts`
- `src/weather/weather.mapper.ts`
- `src/weather/utils/time-change.utils.ts`

Provider:

- Korea Meteorological Administration village forecast API

핵심 구분:

- `baseTime`은 예보 발표 시각이다.
- `fcstTime`은 응답에서 선택할 예보 대상 시각이다.
- `baseTime`과 `fcstTime`을 혼동하지 않는다.

`baseTime` 후보:

- `0200`
- `0500`
- `0800`
- `1100`
- `1400`
- `1700`
- `2000`
- `2300`

`fcstTime` 변환 규칙:

- `00`분부터 `29`분까지는 해당 정시이다.
- `30`분부터 `59`분까지는 다음 정시이다.

예시:

- `08:05` -> `0800`
- `08:22` -> `0800`
- `08:41` -> `0900`
- `07:58` -> `0800`

선택하는 예보 값:

- `PTY`
- `PCP`
- `SNO`

## Weather Adjustment

보정 기준:

- `PTY=0`: `CLEAR`, `+0`
- `PTY=1`: rain
- `PTY=2`: rain and snow
- `PTY=3`: snow
- `PTY=4`: shower

`PTY=1` 기준:

- `PCP < 1`: `RAIN_LIGHT`, `+3`
- `PCP < 5`: `RAIN_NORMAL`, `+5`
- `PCP >= 5`: `RAIN_HEAVY`, `+10`

`PTY=2` 기준:

- `SNO >= 1`: `RAIN_SNOW_HEAVY`, `+15`
- `PCP >= 5`: `RAIN_SNOW`, `+12`
- 그 외: `RAIN_SNOW`, `+10`

`PTY=3` 기준:

- `SNO < 1`: `SNOW`, `+10`
- `SNO >= 1`: `SNOW_HEAVY`, `+15`

`PTY=4` 기준:

- `SHOWER`, `+5`

알 수 없는 값:

- `CLEAR`, `+0`

## Best Route Selection

정렬 기준:

1. 낮은 `predictedTravelMinutes`
2. 낮은 `congestionAdjustMinutes`
3. 낮은 원본 itinerary index

선택된 경로가 결정하는 필드:

- `mapBaseTravelMinutes`
- `congestionAdjustMinutes`
- `weatherAdjustMinutes`
- `predictedTravelMinutes`
- `finalDepartureTime`
- `finalAlarmTime`

## Failure Handling

- API 실패 시 기본 알람을 유지한다.
- API 실패 시 `fallbackUsed`를 반영한다.
- 경로 후보가 없으면 `defaultTravelMinutes`를 사용한다.
- 외부 보정 실패를 전체 계획 실패로 바꾸지 않는다.
- 실패 처리를 바꿀 때는 기준 문서를 먼저 확인한다.
