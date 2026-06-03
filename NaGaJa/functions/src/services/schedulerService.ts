import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import type { Schedule, User } from "../types";
import {
  calculateInitialPlanTimes,
  formatPlanDateKst,
} from "../utils/planTime.utils";
import * as dailyPlanCalculator from "./dailyPlanCalculator";
import { getDailyPlanDocumentId } from "./dailyPlanCalculator";

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

const getDb = (db?: FirestoreDb): FirestoreDb => db ?? admin.firestore();

const dayOfWeekFromPlanDate = (planDate: string): number => {
  const [year, month, day] = planDate.split("-").map(Number);
  const jsDay = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return jsDay === 0 ? 7 : jsDay;
};

const errorMessage = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

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
        if (existing.exists) {
          summary.skippedCount += 1;
          continue;
        }

        const initialTimes = calculateInitialPlanTimes({
          planDate,
          targetArrivalTime: schedule.targetArrivalTime,
          defaultTravelMinutes: user.defaultTravelMinutes,
          prepMinutes: user.prepMinutes,
        });

        await dailyPlanRef.set({
          dailyPlanId,
          scheduleId: scheduleDoc.id,
          planDate,
          title: schedule.title,
          dayOfWeek: schedule.dayOfWeek,
          classTime: schedule.classTime,
          targetArrivalTime: schedule.targetArrivalTime,
          startPlaceName: schedule.startPlaceName,
          destinationName: schedule.destinationName,
          transportMode: schedule.transportMode,
          defaultTravelMinutes: user.defaultTravelMinutes,
          prepMinutes: user.prepMinutes,
          baseDepartureTime: Timestamp.fromDate(initialTimes.baseDepartureAt),
          baseAlarmTime: Timestamp.fromDate(initialTimes.baseAlarmAt),
          calculationTime: Timestamp.fromDate(initialTimes.calculationAt),
          fallbackUsed: false,
          weatherApplied: false,
          congestionApplied: false,
          planStatus: "PENDING",
          createdAt: nowTs,
          updatedAt: nowTs,
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
