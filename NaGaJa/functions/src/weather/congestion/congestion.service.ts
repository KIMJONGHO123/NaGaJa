import { readFile } from "node:fs/promises";
import { getCongestionTimeSlot } from "../utils/time-change.utils";
import { resolveCongestionCsvPath } from "./congestion.paths";
import type { CongestionAdjustResult } from "./congestion.types";

/** CSV에서 혼잡도 계산에 필요한 최소 파싱 구조 */
interface ParsedCongestionCsv {
  routeColumnIndex: number;
  slotColumnIndexByTime: Map<string, number>;
  rows: string[][];
}

/** 같은 파일 재파싱을 막기 위한 메모리 캐시 */
const csvCache = new Map<string, ParsedCongestionCsv>();

/**
 * 노선번호 + 출발예상시각 기준으로 혼잡도 보정시간을 계산한다.
 * - 출발시각을 30분 슬롯으로 변환
 * - 노선별 정류장 승차값 중 상위 30% 평균 계산
 * - 평균값을 LOW/MEDIUM/HIGH 규칙으로 보정시간 변환
 */
export const calculateCongestionByRoute = async (
  routeNo: string,
  departureAt: Date,
  csvPath = resolveCongestionCsvPath(),
): Promise<CongestionAdjustResult> => {
  const normalizedRouteNo = normalizeRouteNo(routeNo);
  const timeSlot = getCongestionTimeSlot(departureAt);
  const parsedCsv = await getParsedCsv(csvPath);
  const slotColumnIndex = parsedCsv.slotColumnIndexByTime.get(timeSlot);

  if (slotColumnIndex === undefined) {
    throw new Error(`승차 컬럼을 찾을 수 없습니다. timeSlot=${timeSlot}`);
  }

  // 해당 노선의 모든 정류장에 대해, 선택된 시간 슬롯 승차건수만 추출
  const boardingCounts = parsedCsv.rows
    .filter((row) =>
      normalizeRouteNo(row[parsedCsv.routeColumnIndex]) === normalizedRouteNo,
    )
    .map((row) => toNumber(row[slotColumnIndex]))
    .filter((value) => Number.isFinite(value));

  if (boardingCounts.length === 0) {
    return {
      routeNo: normalizedRouteNo,
      timeSlot,
      sampledStopCount: 0,
      top30SampleCount: 0,
      top30AverageBoarding: 0,
      congestionLevel: "LOW",
      congestionAdjustMinutes: 0,
    };
  }

  // 혼잡 구간 체감을 반영하기 위해 상위 30% 정류장 평균 사용
  const sorted = [...boardingCounts].sort((a, b) => b - a);
  const top30SampleCount = Math.max(1, Math.ceil(sorted.length * 0.3));
  const top30Values = sorted.slice(0, top30SampleCount);
  const sum = top30Values.reduce((acc, value) => acc + value, 0);
  const top30AverageBoarding = sum / top30Values.length;

  const congestion = toCongestionLevel(top30AverageBoarding);

  return {
    routeNo: normalizedRouteNo,
    timeSlot,
    sampledStopCount: boardingCounts.length,
    top30SampleCount,
    top30AverageBoarding,
    congestionLevel: congestion.level,
    congestionAdjustMinutes: congestion.adjustMinutes,
  };
};

/**
 * CSV를 읽어 파싱하고, 경로/시간 슬롯 조회용 인덱스를 구성한다.
 */
const getParsedCsv = async (csvPath: string): Promise<ParsedCongestionCsv> => {
  const cached = csvCache.get(csvPath);
  if (cached) {
    return cached;
  }

  const raw = await readFile(csvPath, "utf8");
  const lines = raw
    .replace(/^\uFEFF/, "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  if (lines.length < 2) {
    throw new Error("혼잡도 CSV 형식이 올바르지 않습니다.");
  }

  const headers = splitCsvLine(lines[0]).map((header) =>
    header.trim().replace(/^\uFEFF/, ""),
  );
  const routeColumnIndex = headers.findIndex((header) => header === "노선번호");
  if (routeColumnIndex < 0) {
    throw new Error("혼잡도 CSV에서 노선번호 컬럼을 찾지 못했습니다.");
  }

  const slotColumnIndexByTime = new Map<string, number>();
  headers.forEach((header, index) => {
    // 승차 컬럼만 인덱싱(하차 컬럼 제외)
    if (!header.includes("_승차건수")) {
      return;
    }

    const timeSlot = toTimeSlot(header);
    if (timeSlot) {
      slotColumnIndexByTime.set(timeSlot, index);
    }
  });

  const rows = lines.slice(1).map(splitCsvLine);
  const parsed: ParsedCongestionCsv = {
    routeColumnIndex,
    slotColumnIndexByTime,
    rows,
  };
  csvCache.set(csvPath, parsed);

  return parsed;
};

/** 단일 CSV 라인을 컬럼 배열로 분리 */
const splitCsvLine = (line: string): string[] => {
  // 원본 파일은 쉼표 인용(quote) 없이 정수값 위주라 단순 분리로 처리
  return line.split(",");
};

/** "오전8시30분_승차건수" 같은 헤더를 HHMM 슬롯으로 변환 */
const toTimeSlot = (header: string): string | null => {
  const match = header.match(/(오전|오후)(\d+)시(\d+)분_승차건수(?:\(선탑_후탑\))?/);
  if (!match) {
    return null;
  }

  const meridiem = match[1];
  const hour = Number(match[2]);
  const minute = Number(match[3]);

  let hour24 = hour;
  if (meridiem === "오전") {
    hour24 = hour === 12 ? 0 : hour;
  } else {
    hour24 = hour === 12 ? 12 : hour + 12;
  }

  return `${String(hour24).padStart(2, "0")}${String(minute).padStart(2, "0")}`;
};

/** 비정상 값은 0으로 정규화 */
const toNumber = (value: string | undefined): number => {
  if (!value) {
    return 0;
  }

  const parsed = Number(value);
  if (Number.isNaN(parsed)) {
    return 0;
  }
  return parsed;
};

/** 노선번호 비교 전 공백 제거 */
const normalizeRouteNo = (routeNo: string): string => routeNo.trim();

/** 상위 30% 평균 승차값을 혼잡도 레벨/보정시간으로 매핑 */
const toCongestionLevel = (
  avgBoarding: number,
): { level: "LOW" | "MEDIUM" | "HIGH"; adjustMinutes: number } => {
  if (avgBoarding <= 10) {
    return {
      level: "LOW",
      adjustMinutes: 0,
    };
  }

  if (avgBoarding <= 30) {
    return {
      level: "MEDIUM",
      adjustMinutes: 3,
    };
  }

  return {
    level: "HIGH",
    adjustMinutes: 7,
  };
};
