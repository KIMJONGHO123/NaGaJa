/**
 * getTransitData와 동일한 흐름 통합 테스트 (에뮬레이터/실 API)
 * 실행: node scripts/test-getTransitData.mjs
 */
import { readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import admin from "firebase-admin";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const functionsRoot = join(__dirname, "..");

// .env 로드
const envPath = join(functionsRoot, ".env");
for (const line of readFileSync(envPath, "utf8").split("\n")) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith("#")) continue;
  const eq = trimmed.indexOf("=");
  if (eq > 0) {
    process.env[trimmed.slice(0, eq)] = trimmed.slice(eq + 1);
  }
}

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "nagaja-a6a8b";

const { getAddress } = require("../lib/weather/geocoding.service.js");
const { convertToGrid } = require("../lib/weather/utils/grid.utils.js");
const { getTransitSummary } = require("../lib/weather/transit/transit.service.js");
const { TMAP_APP_KEY } = require("../lib/weather/transit/transit.config.js");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "nagaja-a6a8b" });
}

const db = admin.firestore();
const TEST_USER_ID = "test-transit-user";

async function seedSchedule() {
  const userRef = db.collection("users").doc(TEST_USER_ID);
  await userRef.set(
    {
      name: "TransitTest",
      email: "transit-test@test.com",
      prepMinutes: 20,
      defaultTravelMinutes: 30,
      homeWifiSsids: [],
      schoolWifiSsids: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    { merge: true },
  );

  const schedules = await userRef
    .collection("schedules")
    .where("isActive", "==", true)
    .get();

  for (const doc of schedules.docs) {
    await doc.ref.delete();
  }

  await userRef.collection("schedules").add({
    title: "통합테스트",
    dayOfWeek: 1,
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
}

async function runGetTransitDataFlow(userId) {
  console.log("\n=== 1. userId 검증 ===");
  if (!userId) throw new Error("userId is required");
  console.log("OK userId:", userId);

  console.log("\n=== 2. active schedule 조회 ===");
  const schedulesSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("schedules")
    .where("isActive", "==", true)
    .limit(1)
    .get();

  if (schedulesSnapshot.empty) {
    throw new Error("Active schedule not found");
  }

  const scheduleDoc = schedulesSnapshot.docs[0];
  const scheduleData = scheduleDoc.data();
  console.log("OK schedule:", scheduleDoc.id, scheduleData.title);

  console.log("\n=== 3. 카카오 지오코딩 ===");
  const startCoords = await getAddress(scheduleData.startAddress);
  const destinationCoords = await getAddress(scheduleData.destinationAddress);
  console.log("OK start:", startCoords);
  console.log("OK destination:", destinationCoords);

  console.log("\n=== 4. 격자 변환 + DB 저장 ===");
  const startGrid = convertToGrid(
    Number(startCoords.latitude),
    Number(startCoords.longitude),
  );
  const destinationGrid = convertToGrid(
    Number(destinationCoords.latitude),
    Number(destinationCoords.longitude),
  );

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
  console.log("OK Firestore updated");

  console.log("\n=== 5. TMAP 요약 API ===");
  if (!TMAP_APP_KEY) {
    console.warn("SKIP: TMAP_APP_KEY가 비어 있음 (transit.config.ts)");
    return { tmapSkipped: true };
  }

  const coords = {
    startLat: Number(startCoords.latitude),
    startLng: Number(startCoords.longitude),
    endLat: Number(destinationCoords.latitude),
    endLng: Number(destinationCoords.longitude),
    count: 1,
  };

  const departureAt = new Date();
  const transitSummary = await getTransitSummary(coords, departureAt);
  const itineraries = transitSummary?.metaData?.plan?.itineraries ?? [];
  console.log("OK TMAP itineraries count:", itineraries.length);
  if (itineraries[0]) {
    console.log("   pathType:", itineraries[0].pathType);
    console.log("   totalTime(sec):", itineraries[0].totalTime);
    console.log("   totalFare:", itineraries[0].fare?.regular?.totalFare);
  }
  return { tmapSkipped: false, transitSummary };
}

async function main() {
  console.log("Firestore emulator:", process.env.FIRESTORE_EMULATOR_HOST);
  console.log("TMAP_APP_KEY set:", Boolean(TMAP_APP_KEY));

  await seedSchedule();
  const result = await runGetTransitDataFlow(TEST_USER_ID);

  if (result.tmapSkipped) {
    console.log("\n결과: 지오코딩·DB·흐름까지 OK, TMAP만 앱키 필요");
    process.exitCode = 2;
  } else {
    console.log("\n결과: 전체 흐름 OK (TMAP 응답 포함)");
  }
}

main().catch((err) => {
  console.error("\n실패:", err.message);
  if (err.response?.data) console.error("API:", err.response.data);
  if (err.response?.status) console.error("HTTP status:", err.response.status);
  process.exitCode = 1;
});
