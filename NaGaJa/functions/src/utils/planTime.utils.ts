import type { DisplayColor } from "../types/dailyPlan";

/** API 계산 시각 = 기본 준비 알림 시각 − 30분 (규칙 문서 §2) */
export const API_CALCULATION_LEAD_MINUTES = 30;

/** 여유 시간(분) → 알림시계 색상 (문서 예시: 20→GREEN, 5→YELLOW, -5→RED) */
export const MARGIN_GREEN_MINUTES = 15;
export const MARGIN_YELLOW_MINUTES = 0;
const KST_OFFSET_MINUTES = 9 * 60;

const getKstDateParts = (date: Date): {
  year: string;
  month: string;
  day: string;
} => {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const getPart = (type: "year" | "month" | "day"): string => {
    const value = parts.find((part) => part.type === type)?.value;
    if (!value) {
      throw new Error(`Failed to format KST ${type}`);
    }
    return value;
  };

  return {
    year: getPart("year"),
    month: getPart("month"),
    day: getPart("day"),
  };
};

/**
 * planDate(YYYY-MM-DD) + HH:mm → KST 기준 Date
 */
export const combinePlanDateAndTime = (planDate: string, time: string): Date => {
  const [year, month, day] = planDate.split("-").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  return new Date(
    Date.UTC(year, month - 1, day, hour, minute, 0, 0) -
      KST_OFFSET_MINUTES * 60_000,
  );
};

// 기준 시간에 지정한 분(minutes)을 더한 새로운 Date 객체를 반환한다.
export const addMinutes = (date: Date, minutes: number): Date =>
  new Date(date.getTime() + minutes * 60_000);

// 기준 시간에 지정한 분(minutes)을 뺀 새로운 Date 객체를 반환한다.
export const subtractMinutes = (date: Date, minutes: number): Date =>
  addMinutes(date, -minutes);

// 두 시간 사이의 분(minutes) 차이를 반환한다.
export const minutesBetween = (later: Date, earlier: Date): number =>
  Math.round((later.getTime() - earlier.getTime()) / 60_000);

// 초(seconds)를 분(minutes)로 변환하고, 1분 이상의 값을 반환한다.
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
  const { year, month, day } = getKstDateParts(date);
  return `${year}-${month}-${day}`;
};

export const formatBaseDate = (date: Date): string => {
  const { year, month, day } = getKstDateParts(date);
  return `${year}${month}${day}`;
};
