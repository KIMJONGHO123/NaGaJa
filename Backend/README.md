# Backend (Firebase Cloud Functions)

Cloud Functions 소스코드는 [`../NaGaJa/functions/`](../NaGaJa/functions/) 디렉터리에 있습니다.

## Docker로 실행 (권장, 루트 디렉터리에서)
```bash
# 1. 환경 변수 설정
cp .env.example .env
# .env 파일에 실제 API 키 입력

# 2. 서비스 시작
docker compose up -d

# 3. 에뮬레이터 UI 접속
# http://localhost:4000
```

## 직접 실행 (로컬 개발)
```bash
cd NaGaJa/functions
npm install
npm run build
npm run serve   # Firebase 에뮬레이터 시작
```

## 주요 엔드포인트
| 함수명 | 설명 |
|--------|------|
| `generateDailyPlan` | 일일 출발 계획 계산 (날씨+교통+혼잡도) |
| `getTransitData` | TMAP 대중교통 경로 조회 |
| `getWeatherData` | 기상청 단기예보 조회 |
| `getCongestionData` | 버스 혼잡도 계산 |

상세 API 문서: [`../NaGaJa/functions/docs/`](../NaGaJa/functions/docs/)
