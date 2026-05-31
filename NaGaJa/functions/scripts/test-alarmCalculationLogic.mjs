/**
 * Alarm calculation logic regression tests.
 *
 * Run with:
 *   npm run build
 *   node scripts/test-alarmCalculationLogic.mjs
 */
import assert from "assert/strict";
import admin from "firebase-admin";
import { createRequire } from "module";

const require = createRequire(import.meta.url);

const planTime = require("../lib/utils/planTime.utils.js");
const timeChange = require("../lib/weather/utils/time-change.utils.js");
const weatherMapper = require("../lib/weather/weather.mapper.js");
const weatherService = require("../lib/weather/weather.service.js");
const weatherExtract = require("../lib/weather/weather.extract.js");
const transitService = require("../lib/weather/transit/transit.service.js");
const calculator = require("../lib/services/dailyPlanCalculator.js");

const toKstIso = (date) => date.toISOString();

const makeCandidate = (itineraryIndex, predictedTravelMinutes, congestionAdjustMinutes) => ({
  itineraryIndex,
  itinerary: { totalTime: 0 },
  mapBaseTravelMinutes: predictedTravelMinutes,
  estimatedDepartureAt: new Date("2026-05-29T23:00:00.000Z"),
  congestionAdjustMinutes,
  congestionApplied: congestionAdjustMinutes > 0,
  weatherAdjustMinutes: 0,
  weatherType: "CLEAR",
  predictedTravelMinutes,
  busRouteNo: null,
});

function assertTimeCalculations() {
  const initial = planTime.calculateInitialPlanTimes({
    planDate: "2026-05-30",
    targetArrivalTime: "09:00",
    defaultTravelMinutes: 60,
    prepMinutes: 30,
  });

  assert.equal(toKstIso(initial.targetArrivalAt), "2026-05-30T00:00:00.000Z");
  assert.equal(toKstIso(initial.baseDepartureAt), "2026-05-29T23:00:00.000Z");
  assert.equal(toKstIso(initial.baseAlarmAt), "2026-05-29T22:30:00.000Z");
  assert.equal(toKstIso(initial.calculationAt), "2026-05-29T22:00:00.000Z");

  const final = planTime.calculateFinalPlanTimes({
    targetArrivalAt: initial.targetArrivalAt,
    predictedTravelMinutes: 66,
    prepMinutes: 30,
  });

  assert.equal(toKstIso(final.finalDepartureAt), "2026-05-29T22:54:00.000Z");
  assert.equal(toKstIso(final.finalAlarmAt), "2026-05-29T22:24:00.000Z");

  assert.equal(
    planTime.calculateRemainingMarginMinutes({
      targetArrivalAt: initial.targetArrivalAt,
      checkedAt: new Date("2026-05-29T23:00:00.000Z"),
      predictedTravelMinutes: 40,
    }),
    20,
  );
  assert.equal(planTime.toDisplayColor(20), "GREEN");
  assert.equal(planTime.toDisplayColor(5), "YELLOW");
  assert.equal(planTime.toDisplayColor(-5), "RED");
}

function assertDocumentExampleCalculations() {
  const initial = planTime.calculateInitialPlanTimes({
    planDate: "2026-05-30",
    targetArrivalTime: "09:00",
    defaultTravelMinutes: 30,
    prepMinutes: 20,
  });

  assert.equal(toKstIso(initial.baseDepartureAt), "2026-05-29T23:30:00.000Z");
  assert.equal(toKstIso(initial.baseAlarmAt), "2026-05-29T23:10:00.000Z");
  assert.equal(toKstIso(initial.calculationAt), "2026-05-29T22:40:00.000Z");

  const final = planTime.calculateFinalPlanTimes({
    targetArrivalAt: initial.targetArrivalAt,
    predictedTravelMinutes: 45,
    prepMinutes: 20,
  });

  assert.equal(toKstIso(final.finalDepartureAt), "2026-05-29T23:15:00.000Z");
  assert.equal(toKstIso(final.finalAlarmAt), "2026-05-29T22:55:00.000Z");
}

function assertTimeSlotConversions() {
  const atKst = (hhmm) => new Date(`2026-05-29T${hhmm}:00.000Z`);
  const kstDate = (planDate, time) =>
    planTime.combinePlanDateAndTime(planDate, time);

  assert.equal(timeChange.getCongestionTimeSlot(atKst("23:05")), "0800");
  assert.equal(timeChange.getCongestionTimeSlot(atKst("23:22")), "0830");
  assert.equal(timeChange.getCongestionTimeSlot(atKst("23:41")), "0830");
  assert.equal(timeChange.getCongestionTimeSlot(atKst("22:58")), "0800");

  assert.equal(timeChange.getWeatherFcstTime(atKst("23:05")), "0800");
  assert.equal(timeChange.getWeatherFcstTime(atKst("23:22")), "0800");
  assert.equal(timeChange.getWeatherFcstTime(atKst("23:41")), "0900");
  assert.equal(timeChange.getWeatherFcstTime(atKst("22:58")), "0800");

  assert.deepEqual(
    timeChange.getWeatherBaseDateTime(kstDate("2026-05-30", "01:30")),
    { baseDate: "20260529", baseTime: "2300" },
  );
  assert.deepEqual(
    timeChange.getWeatherBaseDateTime(kstDate("2026-05-30", "02:00")),
    { baseDate: "20260530", baseTime: "0200" },
  );
  assert.deepEqual(
    timeChange.getWeatherForecastDateTime(kstDate("2026-05-30", "23:58")),
    { fcstDate: "20260531", fcstTime: "0000" },
  );
  assert.deepEqual(
    timeChange.getWeatherForecastDateTime(kstDate("2026-05-30", "08:41")),
    { fcstDate: "20260530", fcstTime: "0900" },
  );
}

function assertWeatherAdjustments() {
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("0").weatherAdjustMinutes, 0);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("1", "0.5mm").weatherAdjustMinutes, 3);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("1", "3mm").weatherAdjustMinutes, 5);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("1", "5mm").weatherAdjustMinutes, 10);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("2", "1mm", "0cm").weatherAdjustMinutes, 10);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("2", "5mm", "0cm").weatherAdjustMinutes, 12);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("2", "1mm", "1cm").weatherAdjustMinutes, 15);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("3", undefined, "0cm").weatherAdjustMinutes, 10);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("3", undefined, "1cm").weatherAdjustMinutes, 15);
  assert.equal(weatherMapper.mapWeatherToAdjustMinutes("4").weatherAdjustMinutes, 5);
}

function assertRouteSelection() {
  const best = calculator.selectBestRouteCandidate([
    makeCandidate(0, 67, 7),
    makeCandidate(1, 66, 3),
    makeCandidate(2, 67, 0),
  ]);

  assert.equal(best.itineraryIndex, 1);

  const tieByCongestion = calculator.selectBestRouteCandidate([
    makeCandidate(0, 60, 7),
    makeCandidate(1, 60, 3),
    makeCandidate(2, 60, 5),
  ]);

  assert.equal(tieByCongestion.itineraryIndex, 1);

  const tieByOriginalOrder = calculator.selectBestRouteCandidate([
    makeCandidate(2, 60, 3),
    makeCandidate(0, 60, 3),
    makeCandidate(1, 60, 3),
  ]);

  assert.equal(tieByOriginalOrder.itineraryIndex, 0);
  assert.equal(calculator.selectBestRouteCandidate([]), null);
}

function assertWeatherDetailFallbackPolicy() {
  assert.equal(
    calculator.usesMissingWeatherDetailFallback({
      pty: "1",
      fcstDate: "20260530",
      fcstTime: "0800",
    }),
    true,
  );
  assert.equal(
    calculator.usesMissingWeatherDetailFallback({
      pty: "1",
      pcp: "0.5mm",
      fcstDate: "20260530",
      fcstTime: "0800",
    }),
    false,
  );
  assert.equal(
    calculator.usesMissingWeatherDetailFallback({
      pty: "2",
      pcp: "1mm",
      fcstDate: "20260530",
      fcstTime: "0800",
    }),
    true,
  );
  assert.equal(
    calculator.usesMissingWeatherDetailFallback({
      pty: "2",
      pcp: "1mm",
      sno: "0cm",
      fcstDate: "20260530",
      fcstTime: "0800",
    }),
    false,
  );
  assert.equal(
    calculator.usesMissingWeatherDetailFallback({
      pty: "3",
      fcstDate: "20260530",
      fcstTime: "0800",
    }),
    true,
  );
  assert.equal(
    calculator.usesMissingWeatherDetailFallback({
      pty: "0",
      fcstDate: "20260530",
      fcstTime: "0800",
    }),
    false,
  );
}

function createFakeDb() {
  const Timestamp = admin.firestore.Timestamp;
  const writes = [];

  const userData = {
    prepMinutes: 30,
    defaultTravelMinutes: 60,
  };
  const scheduleData = {
    title: "Logic Test",
    dayOfWeek: 6,
    classTime: "09:00",
    targetArrivalTime: "09:00",
    startPlaceName: "Start",
    destinationName: "End",
    transportMode: "BUS",
    startAddress: "Start address",
    destinationAddress: "End address",
    startLat: 35.1,
    startLng: 129.1,
    startNx: 98,
    startNy: 76,
    endLat: 35.2,
    endLng: 129.2,
    endNx: 99,
    endNy: 77,
  };

  const dailyPlansRef = {
    doc: (id) => ({
      id,
      set: async (data) => {
        writes.push({ id, data });
      },
    }),
    where: () => ({
      where: () => ({
        limit: () => ({
          get: async () => ({ empty: true, docs: [] }),
        }),
      }),
    }),
  };

  const schedulesRef = {
    doc: () => ({
      get: async () => ({
        exists: true,
        data: () => scheduleData,
      }),
      update: async () => undefined,
    }),
  };

  const userDoc = {
    get: async () => ({
      exists: true,
      data: () => userData,
    }),
    collection: (name) => {
      if (name === "schedules") {
        return schedulesRef;
      }
      if (name === "dailyPlans") {
        return dailyPlansRef;
      }
      throw new Error(`Unexpected subcollection ${name}`);
    },
  };

  const db = {
    collection: (name) => {
      assert.equal(name, "users");
      return {
        doc: () => userDoc,
      };
    },
  };

  return { db, writes, Timestamp };
}

async function assertFallbackAndWeatherQueryBasis() {
  const { db, writes, Timestamp } = createFakeDb();
  const originalFirestoreDescriptor = Object.getOwnPropertyDescriptor(
    admin,
    "firestore",
  );
  const originalGetWeather = weatherService.getWeather;
  const originalExtractWeatherForecastItems = weatherExtract.extractWeatherForecastItems;
  const originalGetTransitRoutes = transitService.getTransitRoutes;
  const originalWarn = console.warn;

  let weatherCall;

  Object.defineProperty(admin, "firestore", {
    value: Object.assign(() => db, { Timestamp }),
    configurable: true,
  });
  weatherService.getWeather = async (baseDate, baseTime) => {
    weatherCall = { baseDate, baseTime };
    return {};
  };
  weatherExtract.extractWeatherForecastItems = () => [
    {
      baseDate: "20260530",
      baseTime: "0500",
      category: "PTY",
      fcstDate: "20260530",
      fcstTime: "0700",
      fcstValue: "0",
      nx: 98,
      ny: 76,
    },
  ];
  transitService.getTransitRoutes = async () => {
    throw new Error("forced transit failure");
  };
  console.warn = () => undefined;

  try {
    const result = await calculator.calculateAndUpsertDailyPlan({
      userId: "userA",
      scheduleId: "scheduleA",
      planDate: "2026-05-30",
      weatherServiceKey: "test-key",
    });

    assert.deepEqual(weatherCall, { baseDate: "20260530", baseTime: "0500" });
    assert.equal(result.dailyPlanId, "2026-05-30_scheduleA");
    assert.equal(result.plan.fallbackUsed, true);
    assert.equal(result.plan.mapBaseTravelMinutes, 60);
    assert.equal(result.plan.predictedTravelMinutes, 60);
    assert.equal(writes.length, 1);
    assert.equal(writes[0].data.dailyPlanId, "2026-05-30_scheduleA");
  } finally {
    if (originalFirestoreDescriptor) {
      Object.defineProperty(admin, "firestore", originalFirestoreDescriptor);
    } else {
      delete admin.firestore;
    }
    weatherService.getWeather = originalGetWeather;
    weatherExtract.extractWeatherForecastItems = originalExtractWeatherForecastItems;
    transitService.getTransitRoutes = originalGetTransitRoutes;
    console.warn = originalWarn;
  }
}

async function assertSelectedBusRouteNoIsPersisted() {
  const { db, writes, Timestamp } = createFakeDb();
  const originalFirestoreDescriptor = Object.getOwnPropertyDescriptor(
    admin,
    "firestore",
  );
  const originalGetWeather = weatherService.getWeather;
  const originalExtractWeatherForecastItems = weatherExtract.extractWeatherForecastItems;
  const originalGetTransitRoutes = transitService.getTransitRoutes;
  const originalWarn = console.warn;

  Object.defineProperty(admin, "firestore", {
    value: Object.assign(() => db, { Timestamp }),
    configurable: true,
  });
  weatherService.getWeather = async () => ({});
  weatherExtract.extractWeatherForecastItems = () => [
    {
      baseDate: "20260530",
      baseTime: "0500",
      category: "PTY",
      fcstDate: "20260530",
      fcstTime: "0800",
      fcstValue: "0",
      nx: 98,
      ny: 76,
    },
  ];
  transitService.getTransitRoutes = async () => ({
    metaData: {
      requestParameters: {},
      plan: {
        itineraries: [
          {
            pathType: 2,
            totalTime: 60 * 60,
            legs: [
              {
                mode: "BUS",
                sectionTime: 1800,
                route: "간선:100-1",
              },
            ],
          },
        ],
      },
    },
  });
  console.warn = () => undefined;

  try {
    const result = await calculator.calculateAndUpsertDailyPlan({
      userId: "userA",
      scheduleId: "scheduleA",
      planDate: "2026-05-30",
      weatherServiceKey: "test-key",
    });

    assert.equal(result.plan.selectedRouteNo, "100-1");
    assert.equal(writes.length, 1);
    assert.equal(writes[0].data.selectedRouteNo, "100-1");
  } finally {
    if (originalFirestoreDescriptor) {
      Object.defineProperty(admin, "firestore", originalFirestoreDescriptor);
    } else {
      delete admin.firestore;
    }
    weatherService.getWeather = originalGetWeather;
    weatherExtract.extractWeatherForecastItems = originalExtractWeatherForecastItems;
    transitService.getTransitRoutes = originalGetTransitRoutes;
    console.warn = originalWarn;
  }
}

async function main() {
  assertTimeCalculations();
  assertDocumentExampleCalculations();
  assertTimeSlotConversions();
  assertWeatherAdjustments();
  assertRouteSelection();
  assertWeatherDetailFallbackPolicy();
  await assertFallbackAndWeatherQueryBasis();
  await assertSelectedBusRouteNoIsPersisted();

  console.log("Alarm calculation logic regression OK");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
