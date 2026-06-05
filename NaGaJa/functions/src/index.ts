/**
 * Nagaja — Cloud Functions (TypeScript)
 *
 * 리전: asia-northeast3 (서울)
 * 초기화: admin SDK 자동 초기화
 *
 * 새 함수를 추가할 때는 이 파일 또는 src/ 하위 파일에 작성 후
 */


import * as admin from "firebase-admin";
import { defineString } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest,Request } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { Response } from "firebase-functions";

const weatherServiceKey = defineString("WEATHER_SERVICE_KEY");

// import {User, Schedule, DailyPlan} from "./types";
import { createMockUsers } from "./services/userService";
import { createMockSchedules } from "./services/scheduleService";
import { runFullDailyPlanPipeline } from "./services/dailyPlanPipeline";
import {
  calculateDuePendingDailyPlans,
  cleanupOldDailyPlans,
  createPendingDailyPlansForToday,
  recalculateTodayDailyPlanForScheduleWrite,
} from "./services/schedulerService";


// 1. 대중교통 조회
import { getTransitRoutes } from "./weather/transit/transit.service";
import { TransitRoutesCoords } from "./weather/transit/transit.types";
import { calculateCongestionByRoute } from "./weather/congestion";



// 2.날씨 조회
import { getWeather} from "./weather/weather.service";
import { getAddress } from "./weather/geocoding.service";
import { convertToGrid } from "./weather/utils/grid.utils";


// 2. 전역 설정 (함수들보다 먼저 실행되어야 함)
setGlobalOptions({ region: "asia-northeast3" });

// 3. Firebase Admin SDK 초기화 및 DB 인스턴스 생성
admin.initializeApp();

// ======================================================
// 기능 1: 사용자 생성
// ======================================================

export const createUser = onRequest(async (req: Request, res: Response) => {
  await createMockUsers();
  res.status(200).send("Users create successfully");
});

// ======================================================
// 기능 2: 스케줄 등록
// ======================================================

export const createSchedule = onRequest(async (req: Request, res: Response) => {
  // 로직 작성
  await createMockSchedules((req.body.userId));
  res.status(200).send("Schedule create successfully");
});


// ======================================================
// 기능 3: 대중교통 조회
// ======================================================

export const getTransitData = onRequest(async (req: Request, res: Response) => {
  try {
    const userId = req.body.userId;

    if (!userId) {
      res.status(400).json({
        message: "userId is required",
      });
      return;
    }

    // 1. DB에서 스케줄 가져오기
    const schedulesSnapshot = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("schedules")
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (schedulesSnapshot.empty) {
      res.status(404).json({
        message: "Active schedule not found",
      });
      return;
    }

    const scheduleDoc = schedulesSnapshot.docs[0];
    const scheduleData = scheduleDoc.data();

    const startAddress = scheduleData.startAddress;
    const destinationAddress = scheduleData.destinationAddress;

    // 2. 카카오 Local API로 주소 → 위도/경도 변환
    const startCoords = await getAddress(startAddress);
    const destinationCoords = await getAddress(destinationAddress);

    // 3. 출발지, 도착지 위도/경도를 nx,ny로 변환
    const startGrid = convertToGrid(startCoords.latitude, startCoords.longitude);
    const destinationGrid = convertToGrid(destinationCoords.latitude, destinationCoords.longitude);

    // 4. 변환한 위도/경도,nx,ny값값 DB에 저장
    await scheduleDoc.ref.update({
      startLat: startCoords.latitude,
      startLng: startCoords.longitude,
      startNx: startGrid.nx,
      startNy: startGrid.ny,
      endLat: destinationCoords.latitude,
      endLng: destinationCoords.longitude,
      endNx: destinationGrid.nx,
      endNy: destinationGrid.ny,
      updatedAt: new Date(),
    });

    // 5. TMAP API에 넘길 좌표 만들기
    const coords: TransitRoutesCoords = {
      startLat: startCoords.latitude,
      startLng: startCoords.longitude,
      endLat: destinationCoords.latitude,
      endLng: destinationCoords.longitude,
    };

    // 6. 출발 기준 시각
    const departureAt = new Date();

    // 7. TMAP 대중교통 API 호출
    const transitSummary = await getTransitRoutes(coords, departureAt);
    const busRouteNo =
      typeof req.body.routeNo === "string" ? req.body.routeNo : undefined;

    let congestion = null;
    if (busRouteNo) {
      congestion = await calculateCongestionByRoute(busRouteNo, departureAt);
    }

    res.status(200).json({
      message: "TransitData get successfully",
      data: transitSummary,
      congestion,
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Failed to get transit data",
    });
  }
});

// ======================================================
// 기능 4: 버스 혼잡도 계산
// ======================================================

export const getCongestionData = onRequest(
  async (req: Request, res: Response) => {
    try {
      const routeNo =
        typeof req.body.routeNo === "string" ? req.body.routeNo : "";

      if (!routeNo.trim()) {
        res.status(400).json({
          message: "routeNo is required",
        });
        return;
      }

      const departureAtInput =
        typeof req.body.departureAt === "string" ? req.body.departureAt : "";
      const departureAt = departureAtInput
        ? new Date(departureAtInput)
        : new Date();

      if (Number.isNaN(departureAt.getTime())) {
        res.status(400).json({
          message: "departureAt must be a valid datetime string",
        });
        return;
      }

      const congestion = await calculateCongestionByRoute(routeNo, departureAt);

      res.status(200).json({
        message: "CongestionData calculated successfully",
        data: congestion,
      });
    } catch (error) {
      console.error(error);
      res.status(500).json({
        message: "Failed to calculate congestion data",
      });
    }
  },
);


// ======================================================
// 기능 5: 날씨 조회
// ======================================================

export const getWeatherData = onRequest(async (req: Request, res: Response) => {
  // const userDoc = await admin.firestore().collection('users').doc(req.body.userId).get();
  // const userData = userDoc.data(); 
  
  // nx,ny값으로 바꾸기
  const schedules = await admin.firestore().collection('users').doc(req.body.userId).collection('schedules').get();

  const scheduleDoc = schedules.docs[0]; // schedule 문서 중 첫 번째 문서
  const scheduleData  = scheduleDoc.data(); // schedule 문서 중 첫 번째 문서의 데이터

  // console.log("가져온 schedule 문서 ID:", scheduleDoc.id);
  // console.log("가져온 schedule 데이터:", scheduleData);
  
  let geocodingData;
  try {
    geocodingData = await getAddress(scheduleData.startAddress);
    console.log("geocodingData", geocodingData);
  } catch (error: any) {
    console.error("Kakao API error status:", error.response?.status);
    console.error("Kakao API error data:", error.response?.data);
    throw error;
  }

  // 출발지 좌표 업데이트
  await admin
  .firestore()
  .collection('users')
  .doc(req.body.userId)
  .collection('schedules')
  .doc(scheduleDoc.id)
  .update({
    startLat: geocodingData.latitude,//
    startLng: geocodingData.longitude,
  });


  const { nx, ny } = convertToGrid(Number(geocodingData.latitude), Number(geocodingData.longitude));

  const now = new Date();
  
  const baseDate =
       now.getFullYear().toString() +
       String(now.getMonth() + 1).padStart(2, "0") +
       String(now.getDate()).padStart(2, "0");
  const baseTime = '0500';
  const weatherData = await getWeather(
    baseDate,
    baseTime,
    nx,
    ny,
    weatherServiceKey.value(),
  );
  res.status(200).send(weatherData);

});

// ======================================================
// 기능 6: 일일 플랜 최종 계산 파이프라인 실행
// ======================================================

export const generateDailyPlan = onRequest(async (req: Request, res: Response) => {
  try {
    // 사용자 ID 가져오기
    const userId =
      typeof req.body.userId === "string" ? req.body.userId.trim() : "";

    // 사용자 ID 유효성 검사
    if (!userId) {
      res.status(400).json({ message: "userId is required" });
      return;
    }

    // 스케줄 ID 가져오기
    const scheduleId = 
    typeof req.body.scheduleId === "string" ? req.body.scheduleId.trim() : undefined;

    // 플랜 날짜 가져오기
    const planDate =
      typeof req.body.planDate === "string" ? req.body.planDate.trim() : undefined;

    
    // 일일 플랜 최종 계산 파이프라인 실행
    const pipeline = await runFullDailyPlanPipeline({
      userId,
      weatherServiceKey: weatherServiceKey.value(), // 날씨 서비스 키 가져오기
      scheduleId: scheduleId || undefined, // 스케줄 ID 가져오기
      planDate: planDate || undefined, // 플랜 날짜 가져오기
    });

    // 일일 플랜 최종 계산 파이프라인 실행 결과 반환
    res.status(200).json({
      message: "DailyPlan calculated successfully",
      planDate: pipeline.planDate,
      count: pipeline.results.length,
      summary: pipeline.summary,
      data: pipeline.results,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      message: "Failed to generate daily plan",
    });
  }
});

// ======================================================
// 기능 7: 매일 04:00 KST dailyPlan PENDING 생성
// ======================================================

export const cleanupOldDailyPlansBeforeDawn = onSchedule(
  {
    schedule: "30 3 * * *",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const summary = await cleanupOldDailyPlans();
    console.log("cleanupOldDailyPlansBeforeDawn summary", summary);
  },
);

export const createDailyPlansAtDawn = onSchedule(
  {
    schedule: "0 4 * * *",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const summary = await createPendingDailyPlansForToday();
    console.log("createDailyPlansAtDawn summary", summary);
  },
);

// ======================================================
// 기능 8: 10분마다 due PENDING dailyPlan 최종 계산
// ======================================================

export const calculatePendingDailyPlans = onSchedule(
  {
    schedule: "every 10 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const summary = await calculateDuePendingDailyPlans({
      weatherServiceKey: weatherServiceKey.value(),
    });
    console.log("calculatePendingDailyPlans summary", summary);
  },
);

// ======================================================
// 기능 9: 당일 schedule 변경 시 오늘 dailyPlan 즉시 재계산
// ======================================================

export const recalculateTodayDailyPlanOnScheduleWrite = onDocumentWritten(
  "users/{userId}/schedules/{scheduleId}",
  async (event) => {
    const result = await recalculateTodayDailyPlanForScheduleWrite({
      userId: event.params.userId,
      scheduleId: event.params.scheduleId,
      before: event.data?.before.data(),
      after: event.data?.after.data(),
      weatherServiceKey: weatherServiceKey.value(),
    });

    console.log("recalculateTodayDailyPlanOnScheduleWrite result", {
      userId: event.params.userId,
      scheduleId: event.params.scheduleId,
      ...result,
    });
  },
);
