import type { DisplayColor } from "../types/dailyPlan";

/** API 계산 시각 = 기본 준비 알림 시각 − 30분 (규칙 문서 §2) */
export const API_CALCULATION_LEAD_MINUTES = 30;

/** 여유 시간(분) → 알림시계 색상 (문서 예시: 20→GREEN, 5→YELLOW, -5→RED) */
export const MARGIN_GREEN_MINUTES = 15;
export const MARGIN_YELLOW_MINUTES = 0;

/**
 * planDate(YYYY-MM-DD) + HH:mm → KST 기준 Date
 */
export const combinePlanDateAndTime = (planDate: string, time: string): Date => {
  const [year, month, day] = planDate.split("-").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  return new Date(year, month - 1, day, hour, minute, 0, 0);
};

export const addMinutes = (date: Date, minutes: number): Date =>
  new Date(date.getTime() + minutes * 60_000);

export const subtractMinutes = (date: Date, minutes: number): Date =>
  addMinutes(date, -minutes);

export const minutesBetween = (later: Date, earlier: Date): number =>
  Math.round((later.getTime() - earlier.getTime()) / 60_000);

export const ceilSecondsToMinutes = (seconds: number): number =>
  Math.max(1, Math.ceil(seconds / 60));

/**
 * 초기 출발/알람/API 계산 시각 (규칙 문서 §1–2, targetArrival 기준)
 */
export const calculateInitialPlanTimes = (params: {
  planDate: string;
  targetArrivalTime: string;
  defaultTravelMinutes: number;
  prepMinutes: number;
}): {
  targetArrivalAt: Date;
  baseDepartureAt: Date;
  baseAlarmAt: Date;
  calculationAt: Date;
} => {
  const targetArrivalAt = combinePlanDateAndTime(
    params.planDate,
    params.targetArrivalTime,
  );
  const baseDepartureAt = subtractMinutes(
    targetArrivalAt,
    params.defaultTravelMinutes,
  );
  const baseAlarmAt = subtractMinutes(baseDepartureAt, params.prepMinutes);
  const calculationAt = subtractMinutes(
    baseAlarmAt,
    API_CALCULATION_LEAD_MINUTES,
  );

  return {
    targetArrivalAt,
    baseDepartureAt,
    baseAlarmAt,
    calculationAt,
  };
};

/**
 * 최종 출발/알람 시각 (규칙 문서 §18–19)
 */
export const calculateFinalPlanTimes = (params: {
  targetArrivalAt: Date;
  predictedTravelMinutes: number;
  prepMinutes: number;
}): {
  finalDepartureAt: Date;
  finalAlarmAt: Date;
} => {
  const finalDepartureAt = subtractMinutes(
    params.targetArrivalAt,
    params.predictedTravelMinutes,
  );
  const finalAlarmAt = subtractMinutes(finalDepartureAt, params.prepMinutes);

  return { finalDepartureAt, finalAlarmAt };
};

/**
 * 여유 시간 = (목표 도착 − 기준 시각) − 예측 이동시간 (규칙 문서 §42–74)
 */
export const calculateRemainingMarginMinutes = (params: {
  targetArrivalAt: Date;
  checkedAt: Date;
  predictedTravelMinutes: number;
}): number =>
  minutesBetween(params.targetArrivalAt, params.checkedAt) -
  params.predictedTravelMinutes;

export const toDisplayColor = (remainingMarginMinutes: number): DisplayColor => {
  if (remainingMarginMinutes > MARGIN_GREEN_MINUTES) {
    return "GREEN";
  }

  if (remainingMarginMinutes >= MARGIN_YELLOW_MINUTES) {
    return "YELLOW";
  }

  return "RED";
};


/**
 * Date → YYYY-MM-DD 형식 문자열
 */
export const formatPlanDateKst = (date: Date): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

export const formatBaseDate = (date: Date): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}${month}${day}`;
};
