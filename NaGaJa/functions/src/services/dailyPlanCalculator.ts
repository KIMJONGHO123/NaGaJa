import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import type { DailyPlan, Schedule, User } from "../types";
import {
  calculateFinalPlanTimes,
  calculateInitialPlanTimes,
  calculateRemainingMarginMinutes,
  ceilSecondsToMinutes,
  formatBaseDate,
  formatPlanDateKst,
  subtractMinutes,
  toDisplayColor,
} from "../utils/planTime.utils";
import { calculateCongestionByRoute } from "../weather/congestion";
import { getAddress } from "../weather/geocoding.service";
import { convertToGrid } from "../weather/utils/grid.utils";
import {
  getCongestionTimeSlot,
  getWeatherBaseTime,
  getWeatherFcstTime,
} from "../weather/utils/time-change.utils";
import { extractWeatherForecastItems } from "../weather/weather.extract";
import { selectWeatherValuesByTime } from "../weather/weather.filter";
import { mapWeatherToAdjustMinutes } from "../weather/weather.mapper";
import { getWeather } from "../weather/weather.service";
import {
  extractBusRouteNoFromItinerary,
  getItinerariesFromResponse,
  isBusItinerary,
} from "../weather/transit/transit.parser";
import { getTransitRoutes } from "../weather/transit/transit.service";
import type { TransitItinerary } from "../weather/transit/transit.types";
import type { PipelineStepName, PipelineTracer } from "./pipelineTracer";

interface RouteCandidate {
  itineraryIndex: number;
  itinerary: TransitItinerary;
  mapBaseTravelMinutes: number;
  estimatedDepartureAt: Date;
  congestionAdjustMinutes: number;
  congestionApplied: boolean;
  weatherAdjustMinutes: number;
  weatherType: string;
  predictedTravelMinutes: number;
  busRouteNo: string | null;
}

export interface CalculateDailyPlanInput {
  userId: string;
  scheduleId: string;
  planDate: string;
  weatherServiceKey: string;
  tracer?: PipelineTracer;
}

export interface CalculateDailyPlanResult {
  dailyPlanId: string;
  plan: DailyPlan;
}

const isBusTransportMode = (mode: string): boolean =>
  mode.toUpperCase() === "BUS";

/**
 * 규칙 문서 §78~ 흐름: 초기 시각 → TMAP 다경로 → 경로별 혼잡/날씨 → 최단 경로 → DailyPlan 저장
 */
export const calculateAndUpsertDailyPlan = async (
  input: CalculateDailyPlanInput,
): Promise<CalculateDailyPlanResult> => {
  const db = admin.firestore();
  const now = new Date();
  const trace = (step: PipelineStepName, detail?: Record<string, unknown>) =>
    input.tracer?.record(step, detail);

  const userSnap = await db.collection("users").doc(input.userId).get();
  if (!userSnap.exists) {
    throw new Error(`User ${input.userId} not found`);
  }
  const user = userSnap.data() as User;
  trace("load_user", { userId: input.userId });

  const scheduleRef = db
    .collection("users")
    .doc(input.userId)
    .collection("schedules")
    .doc(input.scheduleId);
  const scheduleSnap = await scheduleRef.get();
  if (!scheduleSnap.exists) {
    throw new Error(`Schedule ${input.scheduleId} not found`);
  }
  const schedule = scheduleSnap.data() as Schedule & {
    scheduleId?: string;
  };
  trace("load_schedule", {
    scheduleId: input.scheduleId,
    transportMode: schedule.transportMode,
  });

  const prepMinutes = user.prepMinutes;
  const defaultTravelMinutes = user.defaultTravelMinutes;

  const initialTimes = calculateInitialPlanTimes({
    planDate: input.planDate,
    targetArrivalTime: schedule.targetArrivalTime,
    defaultTravelMinutes,
    prepMinutes,
  });

  let startLat = schedule.startLat;
  let startLng = schedule.startLng;
  let endLat = schedule.endLat;
  let endLng = schedule.endLng;
  let startNx = schedule.startNx;
  let startNy = schedule.startNy;

  if (
    startLat === undefined ||
    startLng === undefined ||
    endLat === undefined ||
    endLng === undefined
  ) {
    const startCoords = await getAddress(schedule.startAddress);
    const endCoords = await getAddress(schedule.destinationAddress);
    trace("geocoding", {
      startAddress: schedule.startAddress,
      endAddress: schedule.destinationAddress,
    });
    const startGrid = convertToGrid(
      Number(startCoords.latitude),
      Number(startCoords.longitude),
    );
    const endGrid = convertToGrid(
      Number(endCoords.latitude),
      Number(endCoords.longitude),
    );

    startLat = Number(startCoords.latitude);
    startLng = Number(startCoords.longitude);
    endLat = Number(endCoords.latitude);
    endLng = Number(endCoords.longitude);
    startNx = startGrid.nx;
    startNy = startGrid.ny;

    await scheduleRef.update({
      startLat,
      startLng,
      startNx,
      startNy,
      endLat,
      endLng,
      endNx: endGrid.nx,
      endNy: endGrid.ny,
      updatedAt: Timestamp.now(),
    });
    trace("schedule_update_coords", { scheduleId: input.scheduleId });
  }

  let fallbackUsed = false;
  let mapBaseTravelMinutes = defaultTravelMinutes;
  let weatherType = "CLEAR";
  let weatherAdjustMinutes = 0;
  let weatherApplied = false;
  let congestionAdjustMinutes = 0;
  let congestionApplied = false;
  let selectedRouteNo: string | null = null;

  const applyBusCongestion =
    isBusTransportMode(schedule.transportMode) ||
    schedule.transportMode.toUpperCase().includes("BUS");

  let weatherItems: ReturnType<typeof extractWeatherForecastItems> = [];
  if (startNx !== undefined && startNy !== undefined) {
    try {
      // 규칙 문서 §11: 날씨 API는 파이프라인 실행 시각(현재) 기준 1회 호출
      const weatherQueryAt = now;
      const weatherBaseTime = getWeatherBaseTime(weatherQueryAt);
      const weatherBaseDate = formatBaseDate(weatherQueryAt);
      const weatherRaw = await getWeather(
        weatherBaseDate,
        weatherBaseTime,
        startNx,
        startNy,
        input.weatherServiceKey,
      );
      weatherItems = extractWeatherForecastItems(weatherRaw);
      trace("weather_api", {
        nx: startNx,
        ny: startNy,
        baseDate: weatherBaseDate,
        baseTime: weatherBaseTime,
        itemCount: weatherItems.length,
      });
    } catch (error) {
      console.warn("Weather API failed, using fallback:", error);
      fallbackUsed = true;
    }
  } else {
    fallbackUsed = true;
  }

  const routeCandidates: RouteCandidate[] = [];
  const congestionLogs: Record<string, unknown>[] = [];

  if (
    startLat !== undefined &&
    startLng !== undefined &&
    endLat !== undefined &&
    endLng !== undefined
  ) {
    try {
      const transitResponse = await getTransitRoutes(
        {
          startLat,
          startLng,
          endLat,
          endLng,
          count: 10,
        },
        initialTimes.calculationAt,
      );

      const itineraries = getItinerariesFromResponse(transitResponse);
      trace("transit_api", { itineraryCount: itineraries.length });
      if (itineraries.length === 0) {
        fallbackUsed = true;
      }

      for (let itineraryIndex = 0; itineraryIndex < itineraries.length; itineraryIndex++) {
        const itinerary = itineraries[itineraryIndex];
        const mapMinutes = ceilSecondsToMinutes(itinerary.totalTime);
        const estimatedDepartureAt = subtractMinutes(
          initialTimes.targetArrivalAt,
          mapMinutes,
        );

        let routeCongestionMinutes = 0;
        let routeCongestionApplied = false;
        const busRouteNo =
          applyBusCongestion && isBusItinerary(itinerary)
            ? extractBusRouteNoFromItinerary(itinerary)
            : null;

        if (busRouteNo) {
          try {
            const congestion = await calculateCongestionByRoute(
              busRouteNo,
              estimatedDepartureAt,
            );
            routeCongestionMinutes = congestion.congestionAdjustMinutes;
            routeCongestionApplied = true;
            congestionLogs.push({
              routeNo: busRouteNo,
              level: congestion.congestionLevel,
              adjustMinutes: congestion.congestionAdjustMinutes,
              success: true,
            });
          } catch (error) {
            console.warn(
              `Congestion failed for route ${busRouteNo}:`,
              error,
            );
            congestionLogs.push({
              routeNo: busRouteNo,
              success: false,
              error: error instanceof Error ? error.message : String(error),
            });
            fallbackUsed = true;
          }
        }

        let routeWeatherMinutes = 0;
        let routeWeatherType = "CLEAR";
        if (weatherItems.length > 0) {
          const fcstTime = getWeatherFcstTime(estimatedDepartureAt);
          const fcstDate = formatBaseDate(estimatedDepartureAt);
          const selected = selectWeatherValuesByTime(
            weatherItems,
            fcstDate,
            fcstTime,
          );
          const weatherAdjust = mapWeatherToAdjustMinutes(
            selected.pty,
            selected.pcp,
            selected.sno,
          );
          routeWeatherMinutes = weatherAdjust.weatherAdjustMinutes;
          routeWeatherType = weatherAdjust.weatherType;
          if (weatherAdjust.weatherAdjustMinutes > 0) {
            weatherApplied = true;
          }
        }

        routeCandidates.push({
          itineraryIndex,
          itinerary,
          mapBaseTravelMinutes: mapMinutes,
          estimatedDepartureAt,
          congestionAdjustMinutes: routeCongestionMinutes,
          congestionApplied: routeCongestionApplied,
          weatherAdjustMinutes: routeWeatherMinutes,
          weatherType: routeWeatherType,
          predictedTravelMinutes:
            mapMinutes + routeCongestionMinutes + routeWeatherMinutes,
          busRouteNo,
        });
      }

      if (congestionLogs.length > 0) {
        const successCount = congestionLogs.filter(
          (l) => l.success === true,
        ).length;
        trace("congestion_api", {
          attemptCount: congestionLogs.length,
          successCount,
          routes: congestionLogs,
        });
      }
    } catch (error) {
      console.warn("TMAP transit failed, using fallback:", error);
      fallbackUsed = true;
    }
  } else {
    fallbackUsed = true;
  }

  if (routeCandidates.length === 0) {
    if (weatherItems.length > 0) {
      const fcstDate = formatBaseDate(initialTimes.calculationAt);
      const fcstTime = getWeatherFcstTime(initialTimes.calculationAt);
      const selected = selectWeatherValuesByTime(
        weatherItems,
        fcstDate,
        fcstTime,
      );
      const weatherAdjust = mapWeatherToAdjustMinutes(
        selected.pty,
        selected.pcp,
        selected.sno,
      );
      weatherType = weatherAdjust.weatherType;
      weatherAdjustMinutes = weatherAdjust.weatherAdjustMinutes;
      weatherApplied = weatherAdjustMinutes > 0;
    }

    mapBaseTravelMinutes = defaultTravelMinutes;
    congestionAdjustMinutes = 0;
    congestionApplied = false;
  } else {
    routeCandidates.sort((a, b) => {
      if (a.predictedTravelMinutes !== b.predictedTravelMinutes) {
        return a.predictedTravelMinutes - b.predictedTravelMinutes;
      }
      if (a.congestionAdjustMinutes !== b.congestionAdjustMinutes) {
        return a.congestionAdjustMinutes - b.congestionAdjustMinutes;
      }
      return a.itineraryIndex - b.itineraryIndex;
    });

    const best = routeCandidates[0];
    trace("route_select", {
      itineraryIndex: best.itineraryIndex,
      busRouteNo: best.busRouteNo,
      predictedTravelMinutes: best.predictedTravelMinutes,
      candidateCount: routeCandidates.length,
    });
    mapBaseTravelMinutes = best.mapBaseTravelMinutes;
    congestionAdjustMinutes = best.congestionAdjustMinutes;
    congestionApplied = best.congestionApplied;
    weatherAdjustMinutes = best.weatherAdjustMinutes;
    weatherType = best.weatherType;
    weatherApplied = best.weatherAdjustMinutes > 0;
    selectedRouteNo = best.busRouteNo;

    if (best.busRouteNo) {
      console.log(
        `Selected route ${best.busRouteNo}, slot ${getCongestionTimeSlot(best.estimatedDepartureAt)}, predicted ${best.predictedTravelMinutes}min`,
      );
    }
  }

  const predictedTravelMinutes =
    routeCandidates.length > 0
      ? routeCandidates[0].predictedTravelMinutes
      : mapBaseTravelMinutes + weatherAdjustMinutes + congestionAdjustMinutes;

  const finalTimes = calculateFinalPlanTimes({
    targetArrivalAt: initialTimes.targetArrivalAt,
    predictedTravelMinutes,
    prepMinutes,
  });

  const displayCheckedAt = now;
  const remainingMarginMinutes = calculateRemainingMarginMinutes({
    targetArrivalAt: initialTimes.targetArrivalAt,
    checkedAt: displayCheckedAt,
    predictedTravelMinutes,
  });
  const displayColor = toDisplayColor(remainingMarginMinutes);

  const nowTs = Timestamp.now();
  const dailyPlan: Omit<DailyPlan, "createdAt"> & { createdAt?: Timestamp } = {
    scheduleId: input.scheduleId,
    planDate: input.planDate,
    title: schedule.title,
    dayOfWeek: schedule.dayOfWeek,
    classTime: schedule.classTime,
    targetArrivalTime: schedule.targetArrivalTime,
    startPlaceName: schedule.startPlaceName,
    destinationName: schedule.destinationName,
    transportMode: schedule.transportMode,
    defaultTravelMinutes,
    prepMinutes,
    baseDepartureTime: Timestamp.fromDate(initialTimes.baseDepartureAt),
    baseAlarmTime: Timestamp.fromDate(initialTimes.baseAlarmAt),
    calculationTime: Timestamp.fromDate(initialTimes.calculationAt),
    weatherType,
    weatherAdjustMinutes,
    weatherCheckedAt: Timestamp.fromDate(initialTimes.calculationAt),
    mapBaseTravelMinutes,
    congestionAdjustMinutes,
    predictedTravelMinutes,
    finalDepartureTime: Timestamp.fromDate(finalTimes.finalDepartureAt),
    finalAlarmTime: Timestamp.fromDate(finalTimes.finalAlarmAt),
    weatherApplied,
    congestionApplied,
    fallbackUsed,
    planStatus: "CALCULATED",
    remainingMarginMinutes,
    displayColor,
    displayCheckedAt: Timestamp.fromDate(displayCheckedAt),
    updatedAt: nowTs,
  };

  const existing = await db
    .collection("users")
    .doc(input.userId)
    .collection("dailyPlans")
    .where("planDate", "==", input.planDate)
    .where("scheduleId", "==", input.scheduleId)
    .limit(1)
    .get();

  let dailyPlanId: string;
  let createdAt = nowTs;
  if (existing.empty) {
    const ref = db
      .collection("users")
      .doc(input.userId)
      .collection("dailyPlans")
      .doc();
    dailyPlanId = ref.id;
    await ref.set({
      ...dailyPlan,
      dailyPlanId,
      createdAt: nowTs,
    });
    trace("firestore_upsert", { dailyPlanId, mode: "create" });
  } else {
    const ref = existing.docs[0].ref;
    dailyPlanId = existing.docs[0].id;
    createdAt = (existing.docs[0].get("createdAt") as Timestamp) ?? nowTs;
    await ref.set({
      ...dailyPlan,
      dailyPlanId,
      createdAt,
    });
    trace("firestore_upsert", { dailyPlanId, mode: "update" });
  }

  if (selectedRouteNo) {
    console.log(`Daily plan ${dailyPlanId} uses bus route ${selectedRouteNo}`);
  }

  return {
    dailyPlanId,
    plan: {
      ...dailyPlan,
      createdAt,
    } as DailyPlan,
  };
};

/**
 * planDate 요일에 맞는 active 스케줄 전부 계산
 */
export const calculateDailyPlansForUser = async (
  userId: string,
  planDate: string,
  weatherServiceKey: string,
  tracer?: PipelineTracer,
): Promise<CalculateDailyPlanResult[]> => {
  const db = admin.firestore();
  const [y, m, d] = planDate.split("-").map(Number);
  const planDay = new Date(y, m - 1, d);
  const jsDay = planDay.getDay();
  const dayOfWeek = jsDay === 0 ? 7 : jsDay;

  const schedulesSnap = await db
    .collection("users")
    .doc(userId)
    .collection("schedules")
    .where("isActive", "==", true)
    .where("dayOfWeek", "==", dayOfWeek)
    .get();

  if (schedulesSnap.empty) {
    throw new Error(
      `No active schedules for user ${userId} on dayOfWeek ${dayOfWeek}`,
    );
  }

  const results: CalculateDailyPlanResult[] = [];
  for (const doc of schedulesSnap.docs) {
    results.push(
      await calculateAndUpsertDailyPlan({
        userId,
        scheduleId: doc.id,
        planDate,
        weatherServiceKey,
        tracer,
      }),
    );
  }

  return results;
};

export const resolvePlanDate = (planDate?: string): string =>
  planDate ?? formatPlanDateKst(new Date());
