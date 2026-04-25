import type { Timestamp } from "firebase-admin/firestore";
import type { TransportMode } from "./schedule";

export type WeatherType = "RAIN" | "SNOW" | "CLEAR" | string;
export type PlanStatus = "CALCULATED" | "FAILED" | string;
export type DisplayColor = "GREEN" | "YELLOW" | "RED";
export type ResultStatus = "ON_TIME" | "LATE" | string;

/** `users/{userId}/dailyPlans/{dailyPlanId}` 문서 */
export interface DailyPlan {
  scheduleId: string;
  planDate: string;
  title: string;
  dayOfWeek: number;
  classTime: string;
  targetArrivalTime: string;
  startPlaceName: string;
  destinationName: string;
  transportMode: TransportMode;
  defaultTravelMinutes: number;
  prepMinutes: number;
  baseDepartureTime: Timestamp;
  baseAlarmTime: Timestamp;
  calculationTime: Timestamp;
  weatherType: WeatherType;
  weatherAdjustMinutes: number;
  weatherCheckedAt: Timestamp;
  mapBaseTravelMinutes: number;
  congestionAdjustMinutes: number;
  predictedTravelMinutes: number;
  finalDepartureTime: Timestamp;
  finalAlarmTime: Timestamp;
  weatherApplied: boolean;
  congestionApplied: boolean;
  fallbackUsed: boolean;
  planStatus: PlanStatus;
  remainingMarginMinutes: number;
  displayColor: DisplayColor;
  displayCheckedAt: Timestamp;
  alarmDismissedAt?: Timestamp;
  departedAt?: Timestamp;
  arrivedAt?: Timestamp;
  actualTravelMinutes?: number;
  resultStatus?: ResultStatus;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
