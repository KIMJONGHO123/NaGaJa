import { createRequire } from "node:module";
import path from "node:path";

const require = createRequire(import.meta.url);
const firebaseToolsLib = path.join(
  process.env.APPDATA || path.join(process.env.USERPROFILE || "", "AppData", "Roaming"),
  "npm",
  "node_modules",
  "firebase-tools",
  "lib",
);
const { configstore } = require(path.join(firebaseToolsLib, "configstore.js"));
const { requireAuth } = require(path.join(firebaseToolsLib, "requireAuth.js"));
const { getAccessToken } = require(path.join(firebaseToolsLib, "auth.js"));

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "nagaja-a6a8b";
const userId = process.argv.find((arg, index) => index > 1 && !arg.startsWith("--")) || "w1yzy4qC94L5reepbhV9";
const verifyOnly = process.argv.includes("--verify");
const databaseId = "(default)";

const KST_OFFSET_MINUTES = 9 * 60;
const firestoreRoot = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents`;
const firestoreNameRoot = `projects/${projectId}/databases/${databaseId}/documents`;

const combinePlanDateAndTime = (planDate, time) => {
  const [year, month, day] = planDate.split("-").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  return new Date(Date.UTC(year, month - 1, day, hour, minute) - KST_OFFSET_MINUTES * 60_000);
};

const addMinutes = (date, minutes) => new Date(date.getTime() + minutes * 60_000);
const subtractMinutes = (date, minutes) => addMinutes(date, -minutes);
const timestamp = (date) => date.toISOString();

const encodePath = (path) => path.split("/").map(encodeURIComponent).join("/");

const toFirestoreValue = (value) => {
  if (value instanceof Date) {
    return { timestampValue: timestamp(value) };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (value === null) {
    return { nullValue: null };
  }
  if (typeof value === "boolean") {
    return { booleanValue: value };
  }
  if (typeof value === "number") {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === "string") {
    return { stringValue: value };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: toFirestoreFields(value) } };
  }
  throw new Error(`Unsupported Firestore value: ${value}`);
};

const toFirestoreFields = (data) =>
  Object.fromEntries(Object.entries(data).map(([key, value]) => [key, toFirestoreValue(value)]));

const fromFirestoreValue = (value) => {
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return new Date(value.timestampValue);
  if ("arrayValue" in value) return (value.arrayValue.values || []).map(fromFirestoreValue);
  if ("nullValue" in value) return null;
  if ("mapValue" in value) return fromFirestoreFields(value.mapValue.fields || {});
  return undefined;
};

const fromFirestoreFields = (fields) =>
  Object.fromEntries(Object.entries(fields || {}).map(([key, value]) => [key, fromFirestoreValue(value)]));

const updateWrite = (path, data) => ({
  update: {
    name: `${firestoreNameRoot}/${path}`,
    fields: toFirestoreFields(data),
  },
  updateMask: {
    fieldPaths: Object.keys(data),
  },
});

const request = async (token, url, options = {}) => {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });

  if (response.status === 404) {
    return null;
  }

  const text = await response.text();
  const body = text ? JSON.parse(text) : {};

  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${JSON.stringify(body)}`);
  }

  return body;
};

const getCliAccessToken = async () => {
  const options = {
    project: projectId,
    user: configstore.get("user"),
    tokens: configstore.get("tokens"),
  };
  await requireAuth(options);
  const tokenResult = await getAccessToken(options.tokens?.refresh_token, options.authScopes || []);
  return tokenResult.access_token;
};

const getDocument = async (token, path) => {
  const body = await request(token, `${firestoreRoot}/${encodePath(path)}`);
  return body?.fields ? fromFirestoreFields(body.fields) : null;
};

const commitWrites = async (token, writes) => {
  const body = await request(token, `${firestoreRoot}:commit`, {
    method: "POST",
    body: JSON.stringify({ writes }),
  });
  return body;
};

const makeDailyPlan = ({
  dailyPlanId,
  scheduleId,
  schedule,
  user,
  planDate,
  now,
}) => {
  const targetArrivalAt = combinePlanDateAndTime(planDate, schedule.targetArrivalTime);
  const baseDepartureAt = subtractMinutes(targetArrivalAt, user.defaultTravelMinutes);
  const baseAlarmAt = subtractMinutes(baseDepartureAt, user.prepMinutes);
  const calculationAt = subtractMinutes(baseAlarmAt, 30);

  return {
    dailyPlanId,
    scheduleId,
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
    baseDepartureTime: baseDepartureAt,
    baseAlarmTime: baseAlarmAt,
    calculationTime: calculationAt,
    weatherType: "CLEAR",
    weatherAdjustMinutes: 0,
    weatherCheckedAt: calculationAt,
    mapBaseTravelMinutes: user.defaultTravelMinutes,
    congestionAdjustMinutes: 0,
    predictedTravelMinutes: user.defaultTravelMinutes,
    selectedRouteNo: null,
    finalDepartureTime: baseDepartureAt,
    finalAlarmTime: baseAlarmAt,
    weatherApplied: false,
    congestionApplied: false,
    fallbackUsed: false,
    planStatus: "PENDING",
    remainingMarginMinutes: 0,
    displayColor: "GREEN",
    displayCheckedAt: now,
    sourceScheduleUpdatedAt: schedule.updatedAt,
    createdAt: now,
    updatedAt: now,
  };
};

const weekdays = [
  {
    key: "monday",
    dayOfWeek: 1,
    planDate: "2026-06-01",
    title: "월요일 테스트 강의",
    classTime: "09:00",
    targetArrivalTime: "08:50",
    destinationName: "월요일 강의실",
  },
  {
    key: "tuesday",
    dayOfWeek: 2,
    planDate: "2026-06-02",
    title: "화요일 테스트 강의",
    classTime: "10:00",
    targetArrivalTime: "09:50",
    destinationName: "화요일 강의실",
  },
  {
    key: "wednesday",
    dayOfWeek: 3,
    planDate: "2026-06-03",
    title: "수요일 테스트 강의",
    classTime: "11:00",
    targetArrivalTime: "10:50",
    destinationName: "수요일 강의실",
  },
  {
    key: "thursday",
    dayOfWeek: 4,
    planDate: "2026-06-04",
    title: "목요일 테스트 강의",
    classTime: "13:00",
    targetArrivalTime: "12:50",
    destinationName: "목요일 강의실",
  },
  {
    key: "friday",
    dayOfWeek: 5,
    planDate: "2026-06-05",
    title: "금요일 테스트 강의",
    classTime: "14:00",
    targetArrivalTime: "13:50",
    destinationName: "금요일 강의실",
  },
];

const token = await getCliAccessToken();
const now = new Date();

if (verifyOnly) {
  const checked = [];
  for (const item of weekdays) {
    const scheduleId = `weekday_${item.key}`;
    const dailyPlanId = `${item.planDate}_${scheduleId}`;
    const schedule = await getDocument(token, `users/${userId}/schedules/${scheduleId}`);
    const dailyPlan = await getDocument(token, `users/${userId}/dailyPlans/${dailyPlanId}`);
    checked.push({
      scheduleId,
      scheduleExists: Boolean(schedule),
      scheduleTitle: schedule?.title,
      scheduleUpdatedAt: schedule?.updatedAt?.toISOString?.(),
      dailyPlanId,
      dailyPlanExists: Boolean(dailyPlan),
      dailyPlanTitle: dailyPlan?.title,
      sourceScheduleUpdatedAt: dailyPlan?.sourceScheduleUpdatedAt?.toISOString?.(),
    });
  }
  console.log(JSON.stringify({ projectId, userId, checked }, null, 2));
  process.exit(0);
}

const existingUser = (await getDocument(token, `users/${userId}`)) || {};
const user = {
  name: existingUser.name || "Weekday Test User",
  email: existingUser.email || "weekday-test@example.com",
  prepMinutes: Number(existingUser.prepMinutes ?? 30),
  defaultTravelMinutes: Number(existingUser.defaultTravelMinutes ?? 35),
  homeWifiSsids: Array.isArray(existingUser.homeWifiSsids) ? existingUser.homeWifiSsids : [],
  schoolWifiSsids: Array.isArray(existingUser.schoolWifiSsids) ? existingUser.schoolWifiSsids : [],
  createdAt: existingUser.createdAt || now,
  updatedAt: now,
};

const writes = [updateWrite(`users/${userId}`, user)];
const written = [];

for (const item of weekdays) {
  const scheduleId = `weekday_${item.key}`;
  const dailyPlanId = `${item.planDate}_${scheduleId}`;
  const schedule = {
    scheduleId,
    userId,
    title: item.title,
    dayOfWeek: item.dayOfWeek,
    classTime: item.classTime,
    targetArrivalTime: item.targetArrivalTime,
    startPlaceName: "테스트 출발지",
    startAddress: "부산광역시 해운대구 센텀중앙로 97",
    startLat: 35.1737,
    startLng: 129.1305,
    startNx: 98,
    startNy: 76,
    destinationName: item.destinationName,
    destinationAddress: "부산광역시 남구 용소로 45",
    endLat: 35.1368,
    endLng: 129.1009,
    endNx: 98,
    endNy: 75,
    transportMode: "BUS",
    isActive: true,
    createdAt: now,
    updatedAt: now,
  };

  writes.push(updateWrite(`users/${userId}/schedules/${scheduleId}`, schedule));
  writes.push(updateWrite(`users/${userId}/dailyPlans/${dailyPlanId}`, makeDailyPlan({
    dailyPlanId,
    scheduleId,
    schedule,
    user,
    planDate: item.planDate,
    now,
  })));

  written.push({ scheduleId, dailyPlanId, dayOfWeek: item.dayOfWeek, planDate: item.planDate });
}

await commitWrites(token, writes);

console.log(JSON.stringify({
  projectId,
  userId,
  written,
}, null, 2));
