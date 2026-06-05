import {createRequire} from "node:module";
import path from "node:path";

const require = createRequire(import.meta.url);
const firebaseToolsLib = path.join(
  process.env.APPDATA || path.join(process.env.USERPROFILE || "", "AppData", "Roaming"),
  "npm",
  "node_modules",
  "firebase-tools",
  "lib",
);
const {configstore} = require(path.join(firebaseToolsLib, "configstore.js"));
const {requireAuth} = require(path.join(firebaseToolsLib, "requireAuth.js"));
const {getAccessToken} = require(path.join(firebaseToolsLib, "auth.js"));

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "nagaja-a6a8b";
const databaseId = "(default)";
const userId = process.argv[2] || "6sGtpoPDLjhRwUcRPMkYBQOMtTE2";
const mode = process.argv[3] || "full";
const planDate = "2026-06-08";
const nextWeekPlanDate = "2026-06-15";
const firstSchedulerNowKst = new Date("2026-06-07T19:00:00.000Z");
const secondSchedulerNowKst = new Date("2026-06-08T01:00:00.000Z");
const generateDailyPlanUrl =
  process.env.GENERATE_DAILY_PLAN_URL ||
  "https://generatedailyplan-fhwhmhyraa-du.a.run.app";

const firestoreRoot = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents`;
const firestoreNameRoot = `projects/${projectId}/databases/${databaseId}/documents`;
const kstOffsetMinutes = 9 * 60;

const encodePath = (pathValue) => pathValue.split("/").map(encodeURIComponent).join("/");

const toFirestoreValue = (value) => {
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(toFirestoreValue)}};
  if (value === null) return {nullValue: null};
  if (typeof value === "boolean") return {booleanValue: value};
  if (typeof value === "number") {
    return Number.isInteger(value) ? {integerValue: String(value)} : {doubleValue: value};
  }
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "object") return {mapValue: {fields: toFirestoreFields(value)}};
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

const request = async (token, url, options = {}) => {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  if (response.status === 404) return null;
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

const getDocument = async (token, docPath) => {
  const body = await request(token, `${firestoreRoot}/${encodePath(docPath)}`);
  return body?.fields ? fromFirestoreFields(body.fields) : null;
};

const listDocuments = async (token, collectionPath) => {
  const body = await request(token, `${firestoreRoot}/${encodePath(collectionPath)}`);
  return (body?.documents || []).map((doc) => ({
    id: doc.name.split("/").pop(),
    data: fromFirestoreFields(doc.fields),
  }));
};

const commitWrites = async (token, writes) =>
  request(token, `${firestoreRoot}:commit`, {
    method: "POST",
    body: JSON.stringify({writes}),
  });

const updateWrite = (docPath, data) => ({
  update: {
    name: `${firestoreNameRoot}/${docPath}`,
    fields: toFirestoreFields(data),
  },
  updateMask: {
    fieldPaths: Object.keys(data),
  },
});

const combinePlanDateAndTime = (dateValue, timeValue) => {
  const [year, month, day] = dateValue.split("-").map(Number);
  const [hour, minute] = timeValue.split(":").map(Number);
  return new Date(Date.UTC(year, month - 1, day, hour, minute) - kstOffsetMinutes * 60_000);
};

const subtractMinutes = (dateValue, minutes) =>
  new Date(dateValue.getTime() - minutes * 60_000);

const subtractCalendarMonthsFromPlanDate = (dateValue, months) => {
  const [year, month, day] = dateValue.split("-").map(Number);
  const targetMonthIndex = month - 1 - months;
  const lastDay = new Date(Date.UTC(year, targetMonthIndex + 1, 0)).getUTCDate();
  const cutoff = new Date(Date.UTC(year, targetMonthIndex, Math.min(day, lastDay)));
  return [
    cutoff.getUTCFullYear(),
    String(cutoff.getUTCMonth() + 1).padStart(2, "0"),
    String(cutoff.getUTCDate()).padStart(2, "0"),
  ].join("-");
};

const cleanupPreview = async (token) => {
  const cutoffDate = subtractCalendarMonthsFromPlanDate("2026-06-08", 6);
  const plans = await listDocuments(token, `users/${userId}/dailyPlans`);
  const candidates = plans
    .filter((plan) => String(plan.data.planDate || "") < cutoffDate)
    .sort((left, right) =>
      String(left.data.planDate || "").localeCompare(String(right.data.planDate || "")),
    )
    .slice(0, 100);

  return {
    cutoffDate,
    checkedCount: candidates.length,
    maxDeleteLimit: 100,
    candidateIds: candidates.slice(0, 10).map((plan) => plan.id),
  };
};

const getTargetSchedule = async (token) => {
  const schedules = await listDocuments(token, `users/${userId}/schedules`);
  const target = schedules.find(
    (schedule) =>
      schedule.data.isActive !== false &&
      Number(schedule.data.dayOfWeek) === 1,
  );
  if (!target) throw new Error(`No active Monday schedule for user ${userId}`);
  return target;
};

const buildPendingDailyPlan = ({dailyPlanId, scheduleId, schedule, user, now}) => {
  const targetArrivalAt = combinePlanDateAndTime(planDate, schedule.targetArrivalTime);
  const baseDepartureAt = subtractMinutes(targetArrivalAt, Number(user.defaultTravelMinutes));
  const baseAlarmAt = subtractMinutes(baseDepartureAt, Number(user.prepMinutes));
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
    defaultTravelMinutes: Number(user.defaultTravelMinutes),
    prepMinutes: Number(user.prepMinutes),
    baseDepartureTime: baseDepartureAt,
    baseAlarmTime: baseAlarmAt,
    calculationTime: calculationAt,
    weatherType: "CLEAR",
    weatherAdjustMinutes: 0,
    weatherCheckedAt: calculationAt,
    mapBaseTravelMinutes: Number(user.defaultTravelMinutes),
    congestionAdjustMinutes: 0,
    predictedTravelMinutes: Number(user.defaultTravelMinutes),
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
    updatedAt: now,
  };
};

const setupTargetSchedule = async (token) => {
  const target = await getTargetSchedule(token);
  const now = new Date();
  const update = {
    title: "다른요일 테스트",
    dayOfWeek: 1,
    classTime: "11:20",
    targetArrivalTime: "11:15",
    startPlaceName: "서면역",
    startAddress: "부산광역시 부산진구 중앙대로 지하730",
    startLat: 35.1578,
    startLng: 129.0592,
    startNx: null,
    startNy: null,
    destinationName: "부산대학교",
    destinationAddress: "부산광역시 금정구 부산대학로63번길 2",
    endLat: 35.2321,
    endLng: 129.0838,
    endNx: null,
    endNy: null,
    transportMode: "BUS",
    isActive: true,
    updatedAt: now,
  };
  await commitWrites(token, [updateWrite(`users/${userId}/schedules/${target.id}`, update)]);
  return {scheduleId: target.id, scheduleUpdatedAt: now.toISOString()};
};

const runFirstSchedulerAtTarget0400 = async (token, scheduleId) => {
  const user = await getDocument(token, `users/${userId}`);
  const schedule = await getDocument(token, `users/${userId}/schedules/${scheduleId}`);
  const dailyPlanId = `${planDate}_${scheduleId}`;
  const existing = await getDocument(token, `users/${userId}/dailyPlans/${dailyPlanId}`);
  const shouldRefresh =
    !existing ||
    (schedule.updatedAt?.getTime?.() ?? 0) >
      (existing.sourceScheduleUpdatedAt?.getTime?.() ?? 0);

  if (!shouldRefresh) {
    return {
      dailyPlanId,
      action: "skipped",
      scheduleUpdatedAt: schedule.updatedAt?.toISOString?.(),
      sourceScheduleUpdatedAt: existing?.sourceScheduleUpdatedAt?.toISOString?.(),
    };
  }

  const pending = buildPendingDailyPlan({
    dailyPlanId,
    scheduleId,
    schedule,
    user,
    now: firstSchedulerNowKst,
  });
  const createdAt = existing?.createdAt || firstSchedulerNowKst;
  await commitWrites(token, [
    updateWrite(`users/${userId}/dailyPlans/${dailyPlanId}`, {
      ...pending,
      createdAt,
    }),
  ]);

  return {
    dailyPlanId,
    action: existing ? "refreshed" : "created",
    planStatus: "PENDING",
    calculationTime: pending.calculationTime.toISOString(),
    sourceScheduleUpdatedAt: pending.sourceScheduleUpdatedAt?.toISOString?.(),
  };
};

const runSecondSchedulerIfDue = async (token, scheduleId, dailyPlanId) => {
  const before = await getDocument(token, `users/${userId}/dailyPlans/${dailyPlanId}`);
  const due =
    before?.planStatus === "PENDING" &&
    before.calculationTime instanceof Date &&
    before.calculationTime.getTime() <= secondSchedulerNowKst.getTime();
  if (!due) {
    return {
      action: "skipped",
      planStatus: before?.planStatus,
      calculationTime: before?.calculationTime?.toISOString?.(),
    };
  }

  const response = await fetch(generateDailyPlanUrl, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({userId, scheduleId, planDate}),
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(`generateDailyPlan failed: ${response.status} ${JSON.stringify(body)}`);
  }
  return {
    action: "calculated",
    status: response.status,
    summary: body.summary,
  };
};

const summarize = (schedule, dailyPlan) => ({
  schedule: {
    title: schedule?.title,
    dayOfWeek: schedule?.dayOfWeek,
    classTime: schedule?.classTime,
    targetArrivalTime: schedule?.targetArrivalTime,
    startPlaceName: schedule?.startPlaceName,
    destinationName: schedule?.destinationName,
    updatedAt: schedule?.updatedAt?.toISOString?.(),
    startLat: schedule?.startLat,
    endLat: schedule?.endLat,
  },
  dailyPlan: {
    planDate: dailyPlan?.planDate,
    planStatus: dailyPlan?.planStatus,
    classTime: dailyPlan?.classTime,
    targetArrivalTime: dailyPlan?.targetArrivalTime,
    startPlaceName: dailyPlan?.startPlaceName,
    destinationName: dailyPlan?.destinationName,
    calculationTime: dailyPlan?.calculationTime?.toISOString?.(),
    finalDepartureTime: dailyPlan?.finalDepartureTime?.toISOString?.(),
    finalAlarmTime: dailyPlan?.finalAlarmTime?.toISOString?.(),
    mapBaseTravelMinutes: dailyPlan?.mapBaseTravelMinutes,
    predictedTravelMinutes: dailyPlan?.predictedTravelMinutes,
    selectedRouteNo: dailyPlan?.selectedRouteNo,
    weatherType: dailyPlan?.weatherType,
    weatherApplied: dailyPlan?.weatherApplied,
    congestionApplied: dailyPlan?.congestionApplied,
    fallbackUsed: dailyPlan?.fallbackUsed,
    sourceScheduleUpdatedAt: dailyPlan?.sourceScheduleUpdatedAt?.toISOString?.(),
    updatedAt: dailyPlan?.updatedAt?.toISOString?.(),
  },
});

const token = await getCliAccessToken();
let targetSchedule = await getTargetSchedule(token);
const result = {projectId, userId, planDate, mode, scheduleId: targetSchedule.id};
result.cleanup0330Preview = await cleanupPreview(token);

if (mode === "setup" || mode === "full") {
  result.setup = await setupTargetSchedule(token);
  targetSchedule = {id: result.setup.scheduleId, data: await getDocument(token, `users/${userId}/schedules/${result.setup.scheduleId}`)};
  result.scheduleId = targetSchedule.id;
}

if (mode === "first" || mode === "full") {
  result.firstScheduler = await runFirstSchedulerAtTarget0400(token, result.scheduleId);
}

if (mode === "second" || mode === "full") {
  const dailyPlanId = `${planDate}_${result.scheduleId}`;
  result.secondScheduler = await runSecondSchedulerIfDue(token, result.scheduleId, dailyPlanId);
}

const finalSchedule = await getDocument(token, `users/${userId}/schedules/${result.scheduleId}`);
const finalDailyPlan = await getDocument(token, `users/${userId}/dailyPlans/${planDate}_${result.scheduleId}`);
const nextWeekDailyPlan = await getDocument(token, `users/${userId}/dailyPlans/${nextWeekPlanDate}_${result.scheduleId}`);
result.final = summarize(finalSchedule, finalDailyPlan);
result.nextWeekDailyPlan = {
  dailyPlanId: `${nextWeekPlanDate}_${result.scheduleId}`,
  exists: Boolean(nextWeekDailyPlan),
  planStatus: nextWeekDailyPlan?.planStatus,
  title: nextWeekDailyPlan?.title,
  sourceScheduleUpdatedAt: nextWeekDailyPlan?.sourceScheduleUpdatedAt?.toISOString?.(),
  updatedAt: nextWeekDailyPlan?.updatedAt?.toISOString?.(),
};

console.log(JSON.stringify(result, null, 2));
