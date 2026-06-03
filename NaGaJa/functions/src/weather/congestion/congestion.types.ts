/** 혼잡도 단계 (규칙: LOW/MEDIUM/HIGH) */
export type CongestionLevel = "LOW" | "MEDIUM" | "HIGH";

/**
 * 노선 + 시간대 기준 혼잡도 계산 결과
 */
export interface CongestionAdjustResult {
  /** 계산 대상 버스 노선번호 */
  routeNo: string;
  /** 혼잡도 계산에 사용된 30분 슬롯 (예: 0800, 0830) */
  timeSlot: string;
  /** 해당 노선에서 샘플링된 정류장 수 */
  sampledStopCount: number;
  /** 상위 30%로 선택된 정류장 수 */
  top30SampleCount: number;
  /** 상위 30% 정류장의 평균 승차 건수 */
  top30AverageBoarding: number;
  /** 혼잡도 단계 */
  congestionLevel: CongestionLevel;
  /** 혼잡도 보정 시간(분) */
  congestionAdjustMinutes: number;
}
