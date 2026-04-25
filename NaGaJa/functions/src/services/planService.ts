import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { DailyPlan } from "../types";

// 특정 사용자 하위에 목업 일일 플랜 데이터 생성

// 저장 위치:
// users/{userId}/dailyPlans/{dailyPlanId}

export const createMockDailyPlans = async (userId: string) => {
  const db = admin.firestore();
  const now = Timestamp.now();

  // users/{userId} 문서 존재 확인
  const userDoc = await db.collection("users").doc(userId).get();

  if (!userDoc.exists) {
    throw new Error(`User ${userId} not found`);
  }

  const mockDailyPlans: DailyPlan[] = [
    {
      scheduleId: "mockScheduleId1",

      planDate: "2026-04-25",

      title: "자료구조",
      dayOfWeek: 1,
      classTime: "09:00",
      targetArrivalTime: "08:55",

      startPlaceName: "집",
      destinationName: "공학관",

      transportMode: "BUS",

      defaultTravelMinutes: 30,
      prepMinutes: 20,

      baseDepartureTime: Timestamp.fromDate(new Date("2026-04-25T08:30:00+09:00")),
      baseAlarmTime: Timestamp.fromDate(new Date("2026-04-25T08:10:00+09:00")),
      calculationTime: Timestamp.fromDate(new Date("2026-04-25T07:40:00+09:00")),

      weatherType: "RAIN",
      weatherAdjustMinutes: 10,
      weatherCheckedAt: Timestamp.fromDate(new Date("2026-04-25T07:40:00+09:00")),

      mapBaseTravelMinutes: 30,
      congestionAdjustMinutes: 5,
      predictedTravelMinutes: 45,

      finalDepartureTime: Timestamp.fromDate(new Date("2026-04-25T08:15:00+09:00")),
      finalAlarmTime: Timestamp.fromDate(new Date("2026-04-25T07:55:00+09:00")),

      weatherApplied: true,
      congestionApplied: true,
      fallbackUsed: false,

      planStatus: "CALCULATED",

      remainingMarginMinutes: 15,
      displayColor: "YELLOW",
      displayCheckedAt: now,

      createdAt: now,
      updatedAt: now,
    },
    {
      scheduleId: "mockScheduleId2",

      planDate: "2026-04-25",

      title: "운영체제",
      dayOfWeek: 3,
      classTime: "10:30",
      targetArrivalTime: "10:25",

      startPlaceName: "집",
      destinationName: "정보관",

      transportMode: "SUBWAY",

      defaultTravelMinutes: 35,
      prepMinutes: 20,

      baseDepartureTime: Timestamp.fromDate(new Date("2026-04-25T09:55:00+09:00")),
      baseAlarmTime: Timestamp.fromDate(new Date("2026-04-25T09:35:00+09:00")),
      calculationTime: Timestamp.fromDate(new Date("2026-04-25T09:05:00+09:00")),

      weatherType: "CLEAR",
      weatherAdjustMinutes: 0,
      weatherCheckedAt: Timestamp.fromDate(new Date("2026-04-25T09:05:00+09:00")),

      mapBaseTravelMinutes: 35,
      congestionAdjustMinutes: 0,
      predictedTravelMinutes: 35,

      finalDepartureTime: Timestamp.fromDate(new Date("2026-04-25T09:55:00+09:00")),
      finalAlarmTime: Timestamp.fromDate(new Date("2026-04-25T09:35:00+09:00")),

      weatherApplied: false,
      congestionApplied: false,
      fallbackUsed: false,

      planStatus: "CALCULATED",

      remainingMarginMinutes: 30,
      displayColor: "GREEN",
      displayCheckedAt: now,

      createdAt: now,
      updatedAt: now,
    },
  ];

  for (const plan of mockDailyPlans) {
    const dailyPlanRef = db
      .collection("users")
      .doc(userId)
      .collection("dailyPlans")
      .doc();

    await dailyPlanRef.set({
      ...plan,
      dailyPlanId: dailyPlanRef.id,
    });
  }
};