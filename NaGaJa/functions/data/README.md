# 혼잡도 CSV 데이터

버스 혼잡도 계산(`calculateCongestionByRoute`)은 **이 폴더의 CSV 파일**을 읽습니다.

## 팀원 설정 (필수)

아래 파일 중 **하나**만 있으면 됩니다. `.env`에 경로를 안 넣어도 자동으로 찾습니다.

| 파일 | 용도 |
|------|------|
| `bus-congestion-busan.csv` | 부산광역시 버스 노선별 승하차 원본 (권장) |
| `sample-bus-congestion.csv` | 소량 샘플 (일부 노선만, 테스트용) |

### 원본 CSV 받는 방법

1. **Git에 포함된 경우** — `git pull` 후 `functions/data/bus-congestion-busan.csv` 확인
2. **없는 경우** — 공유 드라이브/팀원에게 받은  
   `부산광역시_버스노선별 승하차 정보_20230731 (1).csv` 를  
   이 폴더에 **`bus-congestion-busan.csv`** 이름으로 복사

```text
functions/data/bus-congestion-busan.csv
```

### (선택) `.env`로 경로 지정

`functions/.env`:

```env
BUS_CONGESTION_CSV_PATH=./data/bus-congestion-busan.csv
```

## Git 커밋 여부

- `sample-bus-congestion.csv` — 항상 커밋 (용량 작음)
- `bus-congestion-busan.csv` — 약 4MB. 팀이 clone만으로 실행하려면 **커밋 권장**. repo 용량이 부담되면 공유 링크 + 위 복사 방법만 README로 안내

## 동작 확인

```bash
cd functions
npm run test:pipeline
```

`congestion_api` 단계에 `success: true`가 보이면 원본 CSV가 정상 로드된 것입니다.
