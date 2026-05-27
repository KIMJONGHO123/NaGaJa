import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { DailyPlan } from "../types";
import { runFullDailyPlanPipeline } from "./dailyPlanPipeline";

export {
  runFullDailyPlanPipeline,
  type RunFullDailyPlanPipelineResult,
} from "./dailyPlanPipeline";

// 저장 위치:
// users/{userId}/dailyPlans/{dailyPlanId}

/** 실제 API 기반 일일 플랜 계산·저장 */
export const generateDailyPlans = async (
  userId: string,
  weatherServiceKey: string,
  options?: { scheduleId?: string; planDate?: string },
) => {
  const pipeline = await runFullDailyPlanPipeline({
    userId,
    weatherServiceKey,
    scheduleId: options?.scheduleId,
    planDate: options?.planDate,
  });
  return pipeline.results;
};

/** @deprecated 테스트용 목업 — generateDailyPlans 사용 권장 */
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
      classTime: "09:00", // 수업 시작 시각
      targetArrivalTime: "08:55", // 목표 도착 시각

      startPlaceName: "집",
      destinationName: "공학관",

      transportMode: "BUS",

      defaultTravelMinutes: 30, // 기본 이동시간
      prepMinutes: 20, // 준비 시간

      // 08:55 - 30분 = 08:25
      baseDepartureTime: Timestamp.fromDate(
        new Date("2026-04-25T08:25:00+09:00")
      ),

      // 08:25 - 20분 = 08:05
      baseAlarmTime: Timestamp.fromDate(
        new Date("2026-04-25T08:05:00+09:00")
      ),

      // 08:05 - 30분 = 07:35
      calculationTime: Timestamp.fromDate(
        new Date("2026-04-25T07:35:00+09:00")
      ),

      weatherType: "RAIN", // 날씨 상태
      weatherAdjustMinutes: 10, // 날씨 보정시간

      weatherCheckedAt: Timestamp.fromDate(
        new Date("2026-04-25T07:35:00+09:00")
      ),

      mapBaseTravelMinutes: 30, // 지도 API 이동시간
      congestionAdjustMinutes: 5, // 혼잡도 보정시간

      // 30 + 10 + 5 = 45
      predictedTravelMinutes: 45,

      // 08:55 - 45분 = 08:10
      finalDepartureTime: Timestamp.fromDate(
        new Date("2026-04-25T08:10:00+09:00")
      ),

      // 08:10 - 20분 = 07:50
      finalAlarmTime: Timestamp.fromDate(
        new Date("2026-04-25T07:50:00+09:00")
      ),

      weatherApplied: true, // 날씨 보정 적용
      congestionApplied: true, // 혼잡도 보정 적용
      fallbackUsed: false, // fallback 미사용

      planStatus: "CALCULATED", // 계산 완료

      // 08:55 - 07:50 = 65분, 65 - 45 = 20분
      remainingMarginMinutes: 20,

      displayColor: "GREEN", // 여유 상태

      displayCheckedAt: Timestamp.fromDate(
        new Date("2026-04-25T07:50:00+09:00")
      ),

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

      defaultTravelMinutes: 35, // 사용자가 입력한 기본 이동시간, 초기 출발 시각 계산에 사용
      prepMinutes: 20, // 사용자가 입력한 준비 시간, 알람 시각 계산에 사용

      baseDepartureTime: Timestamp.fromDate(new Date("2026-04-25T09:50:00+09:00")), // 초기 출발 시각, 초기 알람 시각 계산에 사용
      baseAlarmTime: Timestamp.fromDate(new Date("2026-04-25T09:30:00+09:00")), // 초기 알람 시각, 초기 출발 시각 계산에 사용
      calculationTime: Timestamp.fromDate(new Date("2026-04-25T09:00:00+09:00")), // Cloud Functions 실행 시각

      // 날씨 상태
      // CLEAR이고 보정 시간이 0분이므로 최종 이동시간에는 영향 없음
      weatherType: "CLEAR",
      weatherAdjustMinutes: 0,

      // 날씨 API를 확인한 시각
      // calculationTime이 09:00이므로, 목업에서는 09:00 기준으로 맞춤
      weatherCheckedAt: Timestamp.fromDate(new Date("2026-04-25T09:00:00+09:00")),

      // 지도 API 기준 기본 이동시간
      // 사용자가 입력한 기본 이동시간과 동일하게 35분으로 설정
      mapBaseTravelMinutes: 35,

      // 이동수단이 SUBWAY이므로 버스 혼잡도 보정은 적용하지 않음
      congestionAdjustMinutes: 0,

      // 최종 예상 이동시간
      // 지도 기본 이동시간 35분 + 날씨 보정 0분 + 혼잡도 보정 0분 = 35분
      predictedTravelMinutes: 35,

      // 목표 도착 시각 10:25에서 최종 예상 이동시간 35분을 뺀 시각
      // 10:25 - 35분 = 09:50
      finalDepartureTime: Timestamp.fromDate(new Date("2026-04-25T09:50:00+09:00")),

      // 최종 출발 시각 09:50에서 준비 시간 20분을 뺀 시각
      // 09:50 - 20분 = 09:30
      finalAlarmTime: Timestamp.fromDate(new Date("2026-04-25T09:30:00+09:00")),

      // 날씨는 조회했지만 CLEAR라서 실제 보정시간은 적용되지 않음
      weatherApplied: false,

      // SUBWAY라서 버스 혼잡도 계산을 적용하지 않음
      congestionApplied: false,

      // API 실패로 기본값을 사용한 상황이 아니므로 false
      fallbackUsed: false,

      // 계산이 정상적으로 완료된 상태
      planStatus: "CALCULATED",

      // displayCheckedAt을 finalAlarmTime인 09:30 기준으로 보면,
      // 목표 도착 시각 10:25까지 55분 남음
      // 55분 - 예상 이동시간 35분 = 20분 여유
      remainingMarginMinutes: 20,

      // 여유 시간이 있으므로 GREEN
      displayColor: "GREEN",

      // 색상 계산 시각
      // 목업 기준으로 finalAlarmTime과 맞춤
      displayCheckedAt: Timestamp.fromDate(new Date("2026-04-25T09:30:00+09:00")),

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