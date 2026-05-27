import { existsSync } from "node:fs";
import { join } from "node:path";

const DATA_DIR = join(__dirname, "../../../data");

/** 팀 공용 부산 승하차 원본 (functions/data에 두면 자동 사용) */
export const BUS_CONGESTION_FULL_CSV = join(
  DATA_DIR,
  "bus-congestion-busan.csv",
);

/** 테스트·노선 없을 때 fallback용 소량 샘플 */
export const BUS_CONGESTION_SAMPLE_CSV = join(
  DATA_DIR,
  "sample-bus-congestion.csv",
);

/**
 * 혼잡도 CSV 경로 결정
 * 1) BUS_CONGESTION_CSV_PATH 환경변수
 * 2) data/bus-congestion-busan.csv (있으면)
 * 3) data/sample-bus-congestion.csv
 */
export const resolveCongestionCsvPath = (override?: string): string => {
  const fromEnv = override ?? process.env.BUS_CONGESTION_CSV_PATH;
  if (fromEnv?.trim()) {
    return fromEnv.trim();
  }

  if (existsSync(BUS_CONGESTION_FULL_CSV)) {
    return BUS_CONGESTION_FULL_CSV;
  }

  return BUS_CONGESTION_SAMPLE_CSV;
};
