import type {
  TransitRoutesCoords,
  TransitRoutesRequest,
} from "./transit.types";

/**
 * 대중교통 API POST 본문 생성
 * 좌표는 문자열(WGS84)로 전달해야 함
 */
export const buildTransitRoutesRequest = (
  coords: TransitRoutesCoords,
): TransitRoutesRequest => {
  const body: TransitRoutesRequest = {
    startX: String(coords.startLng),
    startY: String(coords.startLat),
    endX: String(coords.endLng),
    endY: String(coords.endLat),
    format: "json",
  };

  if (coords.count !== undefined) {
    body.count = coords.count;
  }

  if (coords.searchDttm !== undefined) {
    body.searchDttm = coords.searchDttm;
  }

  return body;
};

/** 하위 호환 alias (기존 코드 호환용) */
export const buildTransitSummaryRequest = buildTransitRoutesRequest;

/**
 * 출발·도착 시각 기준 타임머신 searchDttm (yyyymmddhhmi)
 */
export const formatSearchDttm = (date: Date): string => {
  const pad = (n: number) => String(n).padStart(2, "0");
  return (
    String(date.getFullYear()) +
    pad(date.getMonth() + 1) +
    pad(date.getDate()) +
    pad(date.getHours()) +
    pad(date.getMinutes())
  );
};
