import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import type {DailyPlan, Schedule, User} from "../types";
import {
  calculateInitialPlanTimes,
  formatPlanDateKst,
} from "../utils/planTime.utils";
import * as dailyPlanCalculator from "./dailyPlanCalculator";
import {getDailyPlanDocumentId} from "./dailyPlanCalculator";

type FirestoreDb = FirebaseFirestore.Firestore;

export interface SchedulerInput {
  db?: FirestoreDb;
  now?: Date;
}

export interface FinalCalculationSchedulerInput extends SchedulerInput {
  weatherServiceKey: string;
}

export interface PendingDailyPlanSummary {
  planDate: string;
  userCount: number;
  scheduleCount: number;
  createdCount: number;
  refreshedCount: number;
  skippedCount: number;
  failedCount: number;
  failures: string[];
}

export interface FinalCalculationSummary {
  checkedCount: number;
  processedCount: number;
  failedCount: number;
  failures: string[];
}

export interface CleanupOldDailyPlansSummary {
  cutoffDate: string;
  checkedCount: number;
  deletedCount: number;
  failedCount: number;
  failures: string[];
}

export interface ScheduleWriteRecalculationInput extends SchedulerInput {
  userId: string;
  scheduleId: string;
  before?: Partial<Schedule>;
  after?: Partial<Schedule>;
  weatherServiceKey: string;
}

export interface ScheduleWriteRecalculationResult {
  recalculated: boolean;
  reason:
    | "recalculated"
    | "deleted"
    | "inactive"
    | "not_today"
    | "no_relevant_change";
  planDate: string;
}

const getDb = (db?: FirestoreDb): FirestoreDb => db ?? admin.firestore();

const dayOfWeekFromPlanDate = (planDate: string): number => {
  const [year, month, day] = planDate.split("-").map(Number);
  const jsDay = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return jsDay === 0 ? 7 : jsDay;
};

const errorMessage = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

const subtractCalendarMonthsFromPlanDate = (
  planDate: string,
  months: number,
): string => {
  const [year, month, day] = planDate.split("-").map(Number);
  const targetMonthIndex = month - 1 - months;
  const lastDayOfTargetMonth = new Date(
    Date.UTC(year, targetMonthIndex + 1, 0),
  ).getUTCDate();
  const cutoff = new Date(
    Date.UTC(year, targetMonthIndex, Math.min(day, lastDayOfTargetMonth)),
  );

  return [
    cutoff.getUTCFullYear(),
    String(cutoff.getUTCMonth() + 1).padStart(2, "0"),
    String(cutoff.getUTCDate()).padStart(2, "0"),
  ].join("-");
};

export const resolveDailyPlanCleanupCutoffDate = (
  now: Date,
  retentionMonths = 6,
): string =>
  subtractCalendarMonthsFromPlanDate(formatPlanDateKst(now), retentionMonths);

const scheduleRecalculationFields: Array<keyof Schedule> = [
  "title",
  "dayOfWeek",
  "classTime",
  "startPlaceName",
  "startAddress",
  "startLat",
  "startLng",
  "destinationName",
  "destinationAddress",
  "endLat",
  "endLng",
  "transportMode",
  "isActive",
];

const hasRelevantScheduleChange = (
  before: Partial<Schedule> | undefined,
  after: Partial<Schedule>,
): boolean => {
  if (!before) {
    return true;
  }

  return scheduleRecalculationFields.some(
    (field) => before[field] !== after[field],
  );
};

const compareTimestamp = (
  left: Timestamp | undefined,
  right: Timestamp | undefined,
): number => {
  const leftMs = left?.toMillis() ?? 0;
  const rightMs = right?.toMillis() ?? 0;
  return leftMs < rightMs ? -1 : leftMs > rightMs ? 1 : 0;
};

const shouldRefreshDailyPlanFromSchedule = (
  dailyPlan: Partial<DailyPlan>,
  schedule: Schedule,
): boolean =>
  compareTimestamp(
    schedule.updatedAt,
    dailyPlan.sourceScheduleUpdatedAt,
  ) > 0;

const buildPendingDailyPlanFromSchedule = (input: {
  dailyPlanId: string;
  scheduleId: string;
  planDate: string;
  schedule: Schedule;
  user: User;
  nowTs: Timestamp;
}): Omit<DailyPlan, "createdAt"> => {
  const initialTimes = calculateInitialPlanTimes({
    planDate: input.planDate,
    targetArrivalTime: input.schedule.targetArrivalTime,
    defaultTravelMinutes: input.user.defaultTravelMinutes,
    prepMinutes: input.user.prepMinutes,
  });

  return {
    dailyPlanId: input.dailyPlanId,
    scheduleId: input.scheduleId,
    planDate: input.planDate,
    title: input.schedule.title,
    dayOfWeek: input.schedule.dayOfWeek,
    classTime: input.schedule.classTime,
    targetArrivalTime: input.schedule.targetArrivalTime,
    startPlaceName: input.schedule.startPlaceName,
    destinationName: input.schedule.destinationName,
    transportMode: input.schedule.transportMode,
    defaultTravelMinutes: input.user.defaultTravelMinutes,
    prepMinutes: input.user.prepMinutes,
    baseDepartureTime: Timestamp.fromDate(initialTimes.baseDepartureAt),
    baseAlarmTime: Timestamp.fromDate(initialTimes.baseAlarmAt),
    calculationTime: Timestamp.fromDate(initialTimes.calculationAt),
    weatherType: "CLEAR",
    weatherAdjustMinutes: 0,
    weatherCheckedAt: Timestamp.fromDate(initialTimes.calculationAt),
    mapBaseTravelMinutes: input.user.defaultTravelMinutes,
    congestionAdjustMinutes: 0,
    predictedTravelMinutes: input.user.defaultTravelMinutes,
    selectedRouteNo: null,
    finalDepartureTime: Timestamp.fromDate(initialTimes.baseDepartureAt),
    finalAlarmTime: Timestamp.fromDate(initialTimes.baseAlarmAt),
    weatherApplied: false,
    congestionApplied: false,
    fallbackUsed: false,
    planStatus: "PENDING",
    remainingMarginMinutes: 0,
    displayColor: "GREEN",
    displayCheckedAt: input.nowTs,
    sourceScheduleUpdatedAt: input.schedule.updatedAt,
    updatedAt: input.nowTs,
  };
};

export const recalculateTodayDailyPlanForScheduleWrite = async (
  input: ScheduleWriteRecalculationInput,
): Promise<ScheduleWriteRecalculationResult> => {
  const now = input.now ?? new Date();
  const planDate = formatPlanDateKst(now);
  const todayDayOfWeek = dayOfWeekFromPlanDate(planDate);
  const after = input.after;

  if (!after) {
    return {recalculated: false, reason: "deleted", planDate};
  }

  if (after.isActive !== true) {
    return {recalculated: false, reason: "inactive", planDate};
  }

  if (Number(after.dayOfWeek) !== todayDayOfWeek) {
    return {recalculated: false, reason: "not_today", planDate};
  }

  if (!hasRelevantScheduleChange(input.before, after)) {
    return {recalculated: false, reason: "no_relevant_change", planDate};
  }

  await dailyPlanCalculator.calculateAndUpsertDailyPlan({
    userId: input.userId,
    scheduleId: input.scheduleId,
    planDate,
    weatherServiceKey: input.weatherServiceKey,
  });

  return {recalculated: true, reason: "recalculated", planDate};
};

export const createPendingDailyPlansForToday = async (
  input: SchedulerInput = {},
): Promise<PendingDailyPlanSummary> => {
  const db = getDb(input.db);
  const now = input.now ?? new Date();
  const planDate = formatPlanDateKst(now);
  const dayOfWeek = dayOfWeekFromPlanDate(planDate);
  const nowTs = Timestamp.fromDate(now);
  const summary: PendingDailyPlanSummary = {
    planDate,
    userCount: 0,
    scheduleCount: 0,
    createdCount: 0,
    refreshedCount: 0,
    skippedCount: 0,
    failedCount: 0,
    failures: [],
  };

  const usersSnap = await db.collection("users").get();
  summary.userCount = usersSnap.docs.length;

  for (const userDoc of usersSnap.docs) {
    const user = userDoc.data() as User;
    try {
      const schedulesSnap = await userDoc.ref
        .collection("schedules")
        .where("isActive", "==", true)
        .where("dayOfWeek", "==", dayOfWeek)
        .get();

      for (const scheduleDoc of schedulesSnap.docs) {
        summary.scheduleCount += 1;
        const schedule = scheduleDoc.data() as Schedule;
        const dailyPlanId = getDailyPlanDocumentId(planDate, scheduleDoc.id);
        const dailyPlanRef = userDoc.ref
          .collection("dailyPlans")
          .doc(dailyPlanId);
        const existing = await dailyPlanRef.get();
        const pendingDailyPlan = buildPendingDailyPlanFromSchedule({
          dailyPlanId,
          scheduleId: scheduleDoc.id,
          planDate,
          schedule,
          user,
          nowTs,
        });

        if (existing.exists) {
          const existingDailyPlan = existing.data() as Partial<DailyPlan>;
          if (!shouldRefreshDailyPlanFromSchedule(existingDailyPlan, schedule)) {
            summary.skippedCount += 1;
            continue;
          }

          await dailyPlanRef.set(
            {
              ...pendingDailyPlan,
              createdAt:
                (existingDailyPlan.createdAt as Timestamp | undefined) ??
                nowTs,
            },
            {merge: true},
          );
          summary.refreshedCount += 1;
          continue;
        }

        await dailyPlanRef.set({
          ...pendingDailyPlan,
          createdAt: nowTs,
        });
        summary.createdCount += 1;
      }
    } catch (error) {
      summary.failedCount += 1;
      summary.failures.push(`${userDoc.id}: ${errorMessage(error)}`);
    }
  }

  return summary;
};

export const cleanupOldDailyPlans = async (
  input: SchedulerInput = {},
): Promise<CleanupOldDailyPlansSummary> => {
  const db = getDb(input.db);
  const now = input.now ?? new Date();
  const cutoffDate = resolveDailyPlanCleanupCutoffDate(now);
  const summary: CleanupOldDailyPlansSummary = {
    cutoffDate,
    checkedCount: 0,
    deletedCount: 0,
    failedCount: 0,
    failures: [],
  };

  const oldPlansSnap = await db
    .collectionGroup("dailyPlans")
    .where("planDate", "<", cutoffDate)
    .orderBy("planDate")
    .limit(100)
    .get();

  summary.checkedCount = oldPlansSnap.docs.length;

  for (const dailyPlanDoc of oldPlansSnap.docs) {
    try {
      await dailyPlanDoc.ref.delete();
      summary.deletedCount += 1;
    } catch (error) {
      summary.failedCount += 1;
      summary.failures.push(`${dailyPlanDoc.id}: ${errorMessage(error)}`);
    }
  }

  return summary;
};

const getUserIdFromDailyPlan = (
  dailyPlanDoc: FirebaseFirestore.QueryDocumentSnapshot,
): string => {
  const userRef = dailyPlanDoc.ref.parent.parent;
  if (!userRef) {
    throw new Error(`Missing user parent for dailyPlan ${dailyPlanDoc.id}`);
  }
  return userRef.id;
};

export const calculateDuePendingDailyPlans = async (
  input: FinalCalculationSchedulerInput,
): Promise<FinalCalculationSummary> => {
  const db = getDb(input.db);
  const now = input.now ?? new Date();
  const nowTs = Timestamp.fromDate(now);
  const summary: FinalCalculationSummary = {
    checkedCount: 0,
    processedCount: 0,
    failedCount: 0,
    failures: [],
  };

  const pendingSnap = await db
    .collectionGroup("dailyPlans")
    .where("planStatus", "==", "PENDING")
    .where("calculationTime", "<=", nowTs)
    .get();

  summary.checkedCount = pendingSnap.docs.length;

  for (const dailyPlanDoc of pendingSnap.docs) {
    const data = dailyPlanDoc.data();
    const userId = getUserIdFromDailyPlan(dailyPlanDoc);
    const scheduleId = String(data.scheduleId ?? "");
    const planDate = String(data.planDate ?? "");

    try {
      if (!scheduleId || !planDate) {
        throw new Error("dailyPlan is missing scheduleId or planDate");
      }

      await dailyPlanCalculator.calculateAndUpsertDailyPlan({
        userId,
        scheduleId,
        planDate,
        weatherServiceKey: input.weatherServiceKey,
      });
      summary.processedCount += 1;
    } catch (error) {
      const message = errorMessage(error);
      await dailyPlanDoc.ref.update({
        planStatus: "FAILED",
        failureReason: message,
        updatedAt: Timestamp.now(),
      });
      summary.failedCount += 1;
      summary.failures.push(`${dailyPlanDoc.id}: ${message}`);
    }
  }

  return summary;
};
