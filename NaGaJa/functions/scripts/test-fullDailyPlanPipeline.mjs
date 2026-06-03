/**
 * runFullDailyPlanPipeline 통합 테스트
 * - 각 하위 API(geocoding, weather, transit, congestion) 호출 여부를 steps/summary로 검증
 *
 * 실행 전: Firestore 에뮬레이터 실행 권장
 *   npm run build
 *   node scripts/test-fullDailyPlanPipeline.mjs
 */
import { readFileSync, existsSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import admin from "firebase-admin";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const functionsRoot = join(__dirname, "..");

const envPath = join(functionsRoot, ".env");
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq > 0) {
      const key = trimmed.slice(0, eq).trim();
      const value = trimmed.slice(eq + 1).trim();
      if (!process.env[key]) {
        process.env[key] = value;
      }
    }
  }
}

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "nagaja-a6a8b";

const {
  runFullDailyPlanPipeline,
  assertPipelineSteps,
} = require("../lib/services/dailyPlanPipeline.js");

const TEST_USER_ID = "test-pipeline-user";

const formatPlanDate = (date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
};

const today = new Date();
const TEST_PLAN_DATE = formatPlanDate(today);
const TEST_DAY_OF_WEEK = today.getDay() === 0 ? 7 : today.getDay();

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

const db = admin.firestore();

async function seedUserAndSchedule() {
  const userRef = db.collection("users").doc(TEST_USER_ID);
  await userRef.set(
    {
      name: "PipelineTest",
      email: "pipeline-test@test.com",
      prepMinutes: 20,
      defaultTravelMinutes: 30,
      homeWifiSsids: [],
      schoolWifiSsids: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    { merge: true },
  );

  const schedules = await userRef.collection("schedules").get();
  for (const doc of schedules.docs) {
    await doc.ref.delete();
  }

  const scheduleRef = await userRef.collection("schedules").add({
    title: "파이프라인통합테스트",
    dayOfWeek: TEST_DAY_OF_WEEK,
    classTime: "09:00",
    targetArrivalTime: "08:55",
    startPlaceName: "해운대",
    startAddress: "부산광역시 해운대구 해운대로 620",
    destinationName: "부산대",
    destinationAddress: "부산광역시 금정구 부산대학로 63",
    transportMode: "BUS",
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  return scheduleRef.id;
}

function printSummary(summary, steps) {
  console.log("\n=== 파이프라인 summary ===");
  console.log(JSON.stringify(summary, null, 2));
  console.log("\n=== 파이프라인 steps (최근 20건) ===");
  const tail = steps.slice(-20);
  for (const s of tail) {
    console.log(`  [${s.step}]`, s.detail ? JSON.stringify(s.detail) : "");
  }
}

async function main() {
  const weatherKey = process.env.WEATHER_SERVICE_KEY ?? "";
  const kakaoKey = process.env.KAKAO_REST_API_KEY ?? "";
  const tmapKey = process.env.TMAP_APP_KEY ?? "";
  const fullCsv = join(functionsRoot, "data", "bus-congestion-busan.csv");
  const sampleCsv = join(functionsRoot, "data", "sample-bus-congestion.csv");
  const csvPath =
    process.env.BUS_CONGESTION_CSV_PATH ??
    (existsSync(fullCsv) ? fullCsv : sampleCsv);

  console.log("Firestore emulator:", process.env.FIRESTORE_EMULATOR_HOST);
  console.log("WEATHER_SERVICE_KEY:", Boolean(weatherKey));
  console.log("KAKAO_REST_API_KEY:", Boolean(kakaoKey));
  console.log("TMAP_APP_KEY:", Boolean(tmapKey));
  console.log("BUS_CONGESTION_CSV_PATH:", csvPath || "(미설정)");

  if (!weatherKey) {
    console.error("\n실패: WEATHER_SERVICE_KEY가 .env에 없습니다.");
    process.exitCode = 1;
    return;
  }

  if (!kakaoKey) {
    console.error("\n실패: KAKAO_REST_API_KEY가 .env에 없습니다.");
    process.exitCode = 1;
    return;
  }

  const scheduleId = await seedUserAndSchedule();
  console.log("\nOK seed user/schedule, scheduleId:", scheduleId);

  console.log("\n=== runFullDailyPlanPipeline 실행 ===");
  let pipeline;
  try {
    pipeline = await runFullDailyPlanPipeline({
      userId: TEST_USER_ID,
      scheduleId,
      planDate: TEST_PLAN_DATE,
      weatherServiceKey: weatherKey,
    });
  } catch (error) {
    console.error("\n파이프라인 실행 실패:", error.message);
    if (error.stack) console.error(error.stack);
    process.exitCode = 1;
    return;
  }

  printSummary(pipeline.summary, pipeline.steps);

  const plan = pipeline.results[0]?.plan;
  if (plan) {
    console.log("\n=== 계산된 DailyPlan 요약 ===");
    console.log({
      dailyPlanId: pipeline.results[0].dailyPlanId,
      predictedTravelMinutes: plan.predictedTravelMinutes,
      mapBaseTravelMinutes: plan.mapBaseTravelMinutes,
      congestionAdjustMinutes: plan.congestionAdjustMinutes,
      weatherAdjustMinutes: plan.weatherAdjustMinutes,
      congestionApplied: plan.congestionApplied,
      fallbackUsed: plan.fallbackUsed,
      displayColor: plan.displayColor,
    });
  }

  const congestionStep = pipeline.steps.find(
    (s) => s.step === "congestion_api",
  );
  const congestionSuccessCount =
    typeof congestionStep?.detail?.successCount === "number"
      ? congestionStep.detail.successCount
      : 0;

  const assertion = assertPipelineSteps(pipeline.summary, {
    expectGeocoding: true,
    expectTransit: Boolean(tmapKey),
    expectCongestion: Boolean(csvPath && existsSync(csvPath)),
  });

  const extraErrors = [];
  if (
    csvPath &&
    existsSync(csvPath) &&
    pipeline.summary.congestion_api >= 1 &&
    congestionSuccessCount < 1
  ) {
    extraErrors.push(
      "congestion_api는 시도됐지만 성공한 호출이 없습니다 (CSV·노선번호 확인).",
    );
  }

  if (!assertion.ok) {
    console.error("\n=== 단계 검증 실패 ===");
    for (const err of assertion.errors) {
      console.error(" -", err);
    }
    process.exitCode = 1;
    return;
  }

  if (extraErrors.length > 0) {
    console.error("\n=== 추가 검증 실패 ===");
    for (const err of extraErrors) {
      console.error(" -", err);
    }
    process.exitCode = 1;
    return;
  }

  console.log("\n결과: 전체 파이프라인 OK — 하위 API 호출 검증 통과");
  console.log("congestion 성공 호출:", congestionSuccessCount);

  if (!tmapKey) {
    console.warn(
      "\n참고: TMAP_APP_KEY 없음 → transit 검증을 건너뜀. 키 설정 후 재실행 권장.",
    );
    process.exitCode = 2;
  }

  if (!csvPath || !existsSync(csvPath)) {
    console.warn(
      "\n참고: BUS_CONGESTION_CSV_PATH 미설정 → congestion 검증을 건너뜀.",
    );
  }
}

main().catch((err) => {
  console.error("\n실패:", err.message);
  if (err.response?.data) console.error("API:", err.response.data);
  process.exitCode = 1;
});
