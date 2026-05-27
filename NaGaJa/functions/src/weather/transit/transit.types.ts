/**
 * TMAP 대중교통 API 타입
 */

/** 경로 탐색 결과 종류 (pathType) */
export type TransitPathType =
  | 1 // 지하철
  | 2 // 버스
  | 3 // 버스+지하철
  | 4 // 고속/시외버스
  | 5 // 기차
  | 6 // 항공
  | 7; // 해운

/** API 요청 본문 (WGS84 좌표) */
export interface TransitRoutesRequest {
  /** 출발지 경도 */
  startX: string;
  /** 출발지 위도 */
  startY: string;
  /** 도착지 경도 */
  endX: string;
  /** 도착지 위도 */
  endY: string;
  /** 출력 포맷 (기본 json) */
  format?: "json" | "xml";
  /** 최대 응답 결과 개수 1~10 (기본 10) */
  count?: number;
  /** 타임머신 검색 시각 yyyymmddhhmi */
  searchDttm?: string;
}

/** 숫자 좌표로 대중교통 경로를 조회할 때 사용 */
export interface TransitRoutesCoords {
  startLng: number;
  startLat: number;
  endLng: number;
  endLat: number;
  count?: number;
  searchDttm?: string;
}

export interface TransitFareCurrency {
  symbol: string;
  currency: string;
  currencyCode: string;
}

export interface TransitFareRegular {
  totalFare: number;
  currency: TransitFareCurrency;
}

export interface TransitFare {
  regular: TransitFareRegular;
}

/** 경로 구간 (TMAP legs) */
export interface TransitLeg {
  mode?: string;
  sectionTime?: number;
  distance?: number;
  route?: string;
  routeId?: string;
  routeColor?: string;
}

/** 단일 경로 요약 */
export interface TransitItinerary {
  pathType?: TransitPathType;
  /** 총 소요시간(초) */
  totalTime: number;
  transferCount?: number;
  totalWalkDistance?: number;
  totalDistance?: number;
  totalWalkTime?: number;
  fare?: TransitFare;
  legs?: TransitLeg[];
}

export interface TransitRequestParameters {
  reqDttm: string;
  startX: string;
  startY: string;
  endX: string;
  endY: string;
}

export interface TransitPlan {
  itineraries: TransitItinerary[];
}

export interface TransitMetaData {
  requestParameters: TransitRequestParameters;
  plan: TransitPlan;
}

/** 대중교통 API 응답 루트 */
export interface TransitRoutesResponse {
  metaData: TransitMetaData;
}

/** 하위 호환 alias (기존 코드 호환용) */
export type TransitSummaryRequest = TransitRoutesRequest;
export type TransitSummaryCoords = TransitRoutesCoords;
export type TransitSummaryResponse = TransitRoutesResponse;
