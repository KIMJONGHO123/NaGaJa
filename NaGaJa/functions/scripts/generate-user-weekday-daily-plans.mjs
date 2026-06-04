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
const userId = process.argv.find((arg, index) => index > 1 && !arg.startsWith("--"));
const baseMonday = process.argv.find((arg) => /^\d{4}-\d{2}-\d{2}$/.test(arg)) || "2026-06-01";
const databaseId = "(default)";
const generateDailyPlanUrl =
  process.env.GENERATE_DAILY_PLAN_URL ||
  "https://generatedailyplan-fhwhmhyraa-du.a.run.app";

if (!userId) {
  throw new Error("Usage: node scripts/generate-user-weekday-daily-plans.mjs <userId> [YYYY-MM-DD-monday]");
}

const firestoreRoot = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents`;

const encodePath = (pathValue) => pathValue.split("/").map(encodeURIComponent).join("/");

const addDays = (date, days) => {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
};

const formatDate = (date) => date.toISOString().slice(0, 10);

const planDateForDayOfWeek = (dayOfWeek) => {
  const monday = new Date(`${baseMonday}T00:00:00.000Z`);
  return formatDate(addDays(monday, Number(dayOfWeek) - 1));
};

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

const listSchedules = async (token) => {
  const body = await request(token, `${firestoreRoot}/${encodePath(`users/${userId}/schedules`)}`);
  return (body?.documents || []).map((doc) => ({
    id: doc.name.split("/").pop(),
    data: fromFirestoreFields(doc.fields),
  }));
};

const getDailyPlan = async (token, dailyPlanId) => {
  const body = await request(token, `${firestoreRoot}/${encodePath(`users/${userId}/dailyPlans/${dailyPlanId}`)}`);
  return body?.fields ? fromFirestoreFields(body.fields) : null;
};

const callGenerateDailyPlan = async ({ scheduleId, planDate }) => {
  const response = await fetch(generateDailyPlanUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ userId, scheduleId, planDate }),
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : {};
  return {
    ok: response.ok,
    status: response.status,
    body,
  };
};

const token = await getCliAccessToken();
const schedules = (await listSchedules(token))
  .filter((schedule) => schedule.data.isActive !== false)
  .filter((schedule) => Number(schedule.data.dayOfWeek) >= 1 && Number(schedule.data.dayOfWeek) <= 7)
  .sort((left, right) => Number(left.data.dayOfWeek) - Number(right.data.dayOfWeek));

const results = [];

for (const schedule of schedules) {
  const planDate = planDateForDayOfWeek(schedule.data.dayOfWeek);
  const call = await callGenerateDailyPlan({ scheduleId: schedule.id, planDate });
  const dailyPlanId = call.body?.data?.[0]?.dailyPlanId || `${planDate}_${schedule.id}`;
  const dailyPlan = await getDailyPlan(token, dailyPlanId);
  results.push({
    scheduleId: schedule.id,
    title: schedule.data.title,
    dayOfWeek: schedule.data.dayOfWeek,
    planDate,
    callStatus: call.status,
    callOk: call.ok,
    responseMessage: call.body?.message,
    responseSummary: call.body?.summary,
    dailyPlanId,
    dailyPlanExists: Boolean(dailyPlan),
    planStatus: dailyPlan?.planStatus,
    dailyPlanTitle: dailyPlan?.title,
    sourceScheduleUpdatedAt: dailyPlan?.sourceScheduleUpdatedAt?.toISOString?.(),
  });
}

console.log(JSON.stringify({
  projectId,
  userId,
  baseMonday,
  count: results.length,
  results,
}, null, 2));
