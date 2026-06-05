/**
 * Scheduler service regression tests.
 *
 * Run with:
 *   npm run build
 *   node scripts/test-schedulerService.mjs
 */
import assert from "assert/strict";
import admin from "firebase-admin";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
const Timestamp = admin.firestore.Timestamp;

const scheduler = require("../lib/services/schedulerService.js");
const calculator = require("../lib/services/dailyPlanCalculator.js");

const toTimestamp = (iso) => Timestamp.fromDate(new Date(iso));

class FakeDocSnapshot {
  constructor(id, ref, data) {
    this.id = id;
    this.ref = ref;
    this.exists = data !== undefined;
    this._data = data;
  }

  data() {
    return this._data;
  }

  get(field) {
    return this._data?.[field];
  }
}

class FakeDocRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split("/").pop();
    const parentPath = path.split("/").slice(0, -1).join("/");
    this.parent = new FakeCollectionRef(db, parentPath);
  }

  collection(name) {
    return new FakeCollectionRef(this.db, `${this.path}/${name}`);
  }

  async get() {
    return new FakeDocSnapshot(this.id, this, this.db.docs.get(this.path));
  }

  async set(data, options) {
    const previous = this.db.docs.get(this.path);
    this.db.docs.set(
      this.path,
      options?.merge && previous ? { ...previous, ...data } : data,
    );
    this.db.writes.push({ type: "set", path: this.path, data, options });
  }

  async update(data) {
    const previous = this.db.docs.get(this.path);
    if (!previous) {
      throw new Error(`Missing document ${this.path}`);
    }
    this.db.docs.set(this.path, { ...previous, ...data });
    this.db.writes.push({ type: "update", path: this.path, data });
  }

  async delete() {
    this.db.docs.delete(this.path);
    this.db.writes.push({ type: "delete", path: this.path });
  }
}

class FakeCollectionRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split("/").pop();
    const parentParts = path.split("/").slice(0, -1);
    this.parent = parentParts.length % 2 === 0 && parentParts.length > 0
      ? new FakeDocRef(db, parentParts.join("/"))
      : null;
  }

  doc(id) {
    return new FakeDocRef(this.db, `${this.path}/${id}`);
  }

  where(field, op, value) {
    return new FakeQuery(this.db, this.path, [{ field, op, value }]);
  }

  async get() {
    return queryDocs(this.db, this.path, []);
  }
}

class FakeQuery {
  constructor(db, path, filters, orderField = null, limitCount = null) {
    this.db = db;
    this.path = path;
    this.filters = filters;
    this.orderField = orderField;
    this.limitCount = limitCount;
  }

  where(field, op, value) {
    return new FakeQuery(this.db, this.path, [
      ...this.filters,
      { field, op, value },
    ], this.orderField, this.limitCount);
  }

  orderBy(field) {
    return new FakeQuery(this.db, this.path, this.filters, field, this.limitCount);
  }

  limit(count) {
    return new FakeQuery(this.db, this.path, this.filters, this.orderField, count);
  }

  async get() {
    return queryDocs(this.db, this.path, this.filters, this.orderField, this.limitCount);
  }
}

class FakeCollectionGroupQuery {
  constructor(db, collectionId, filters, orderField = null, limitCount = null) {
    this.db = db;
    this.collectionId = collectionId;
    this.filters = filters;
    this.orderField = orderField;
    this.limitCount = limitCount;
  }

  where(field, op, value) {
    return new FakeCollectionGroupQuery(this.db, this.collectionId, [
      ...this.filters,
      { field, op, value },
    ], this.orderField, this.limitCount);
  }

  orderBy(field) {
    return new FakeCollectionGroupQuery(this.db, this.collectionId, this.filters, field, this.limitCount);
  }

  limit(count) {
    return new FakeCollectionGroupQuery(this.db, this.collectionId, this.filters, this.orderField, count);
  }

  async get() {
    const docs = [];
    for (const [path, data] of this.db.docs.entries()) {
      const parts = path.split("/");
      if (parts.length >= 2 && parts[parts.length - 2] === this.collectionId) {
        if (matchesFilters(data, this.filters)) {
          docs.push(new FakeDocSnapshot(parts[parts.length - 1], new FakeDocRef(this.db, path), data));
        }
      }
    }
    return applyQueryOptions(docs, this.orderField, this.limitCount);
  }
}

class FakeDb {
  constructor(seed) {
    this.docs = new Map(Object.entries(seed));
    this.writes = [];
  }

  collection(path) {
    return new FakeCollectionRef(this, path);
  }

  collectionGroup(collectionId) {
    return new FakeCollectionGroupQuery(this, collectionId, []);
  }
}

function queryDocs(db, collectionPath, filters, orderField = null, limitCount = null) {
  const docs = [];
  const prefix = `${collectionPath}/`;
  for (const [path, data] of db.docs.entries()) {
    if (!path.startsWith(prefix)) continue;
    const remainder = path.slice(prefix.length);
    if (remainder.includes("/")) continue;
    if (matchesFilters(data, filters)) {
      docs.push(new FakeDocSnapshot(remainder, new FakeDocRef(db, path), data));
    }
  }
  return applyQueryOptions(docs, orderField, limitCount);
}

function applyQueryOptions(docs, orderField, limitCount) {
  let result = docs;
  if (orderField) {
    result = [...result].sort((left, right) =>
      compareValues(left.get(orderField), right.get(orderField)),
    );
  }
  if (limitCount != null) {
    result = result.slice(0, limitCount);
  }
  return { empty: result.length === 0, docs: result };
}

function matchesFilters(data, filters) {
  return filters.every(({ field, op, value }) => {
    if (op === "==") return data[field] === value;
    if (op === "<=") return compareValues(data[field], value) <= 0;
    if (op === "<") return compareValues(data[field], value) < 0;
    throw new Error(`Unsupported op ${op}`);
  });
}

function compareValues(left, right) {
  const leftMs = typeof left?.toMillis === "function" ? left.toMillis() : left;
  const rightMs = typeof right?.toMillis === "function" ? right.toMillis() : right;
  return leftMs < rightMs ? -1 : leftMs > rightMs ? 1 : 0;
}

function baseSeed() {
  return {
    "users/userA": {
      prepMinutes: 40,
      defaultTravelMinutes: 80,
      createdAt: toTimestamp("2026-05-01T00:00:00.000Z"),
      updatedAt: toTimestamp("2026-05-01T00:00:00.000Z"),
    },
    "users/userB": {
      prepMinutes: 10,
      defaultTravelMinutes: 20,
      createdAt: toTimestamp("2026-05-01T00:00:00.000Z"),
      updatedAt: toTimestamp("2026-05-01T00:00:00.000Z"),
    },
    "users/userA/schedules/scheduleA": {
      title: "Early Class",
      dayOfWeek: 7,
      classTime: "07:00",
      targetArrivalTime: "06:50",
      startPlaceName: "Home",
      startAddress: "Home address",
      destinationName: "School",
      destinationAddress: "School address",
      transportMode: "BUS",
      isActive: true,
      createdAt: toTimestamp("2026-05-01T00:00:00.000Z"),
      updatedAt: toTimestamp("2026-05-01T00:00:00.000Z"),
    },
    "users/userA/schedules/scheduleWrongDay": {
      title: "Wrong Day",
      dayOfWeek: 1,
      classTime: "09:00",
      targetArrivalTime: "08:50",
      startPlaceName: "Home",
      startAddress: "Home address",
      destinationName: "School",
      destinationAddress: "School address",
      transportMode: "BUS",
      isActive: true,
      createdAt: toTimestamp("2026-05-01T00:00:00.000Z"),
      updatedAt: toTimestamp("2026-05-01T00:00:00.000Z"),
    },
    "users/userB/schedules/scheduleInactive": {
      title: "Inactive",
      dayOfWeek: 7,
      classTime: "10:00",
      targetArrivalTime: "09:50",
      startPlaceName: "Home",
      startAddress: "Home address",
      destinationName: "School",
      destinationAddress: "School address",
      transportMode: "BUS",
      isActive: false,
      createdAt: toTimestamp("2026-05-01T00:00:00.000Z"),
      updatedAt: toTimestamp("2026-05-01T00:00:00.000Z"),
    },
  };
}

async function assertPendingPlansAreCreatedForTodayOnly() {
  const db = new FakeDb(baseSeed());
  const result = await scheduler.createPendingDailyPlansForToday({
    db,
    now: new Date("2026-05-30T19:00:00.000Z"),
  });

  assert.equal(result.planDate, "2026-05-31");
  assert.equal(result.createdCount, 1);
  assert.equal(result.refreshedCount, 0);
  assert.equal(result.skippedCount, 0);

  const plan = db.docs.get("users/userA/dailyPlans/2026-05-31_scheduleA");
  assert.ok(plan);
  assert.equal(plan.dailyPlanId, "2026-05-31_scheduleA");
  assert.equal(plan.scheduleId, "scheduleA");
  assert.equal(plan.planDate, "2026-05-31");
  assert.equal(plan.planStatus, "PENDING");
  assert.equal(plan.sourceScheduleUpdatedAt.toDate().toISOString(), "2026-05-01T00:00:00.000Z");
  assert.equal(plan.baseDepartureTime.toDate().toISOString(), "2026-05-30T20:30:00.000Z");
  assert.equal(plan.baseAlarmTime.toDate().toISOString(), "2026-05-30T19:50:00.000Z");
  assert.equal(plan.calculationTime.toDate().toISOString(), "2026-05-30T19:20:00.000Z");
  assert.equal(db.docs.has("users/userA/dailyPlans/2026-05-31_scheduleWrongDay"), false);
  assert.equal(db.docs.has("users/userB/dailyPlans/2026-05-31_scheduleInactive"), false);
}

async function assertFridayPlanIsNotCreatedWhenFridayScheduleWasDisabledOnTuesday() {
  const seed = {
    "users/userA": {
      prepMinutes: 30,
      defaultTravelMinutes: 40,
      createdAt: toTimestamp("2026-06-01T00:00:00.000Z"),
      updatedAt: toTimestamp("2026-06-01T00:00:00.000Z"),
    },
    "users/userA/schedules/fridaySchedule": {
      title: "Friday Disabled",
      dayOfWeek: 5,
      classTime: "10:00",
      targetArrivalTime: "09:55",
      startPlaceName: "Home",
      startAddress: "Home address",
      destinationName: "School",
      destinationAddress: "School address",
      transportMode: "BUS",
      isActive: false,
      createdAt: toTimestamp("2026-06-01T00:00:00.000Z"),
      updatedAt: toTimestamp("2026-06-09T03:00:00.000Z"),
    },
  };
  const db = new FakeDb(seed);

  const result = await scheduler.createPendingDailyPlansForToday({
    db,
    now: new Date("2026-06-11T19:00:00.000Z"),
  });

  assert.equal(result.planDate, "2026-06-12");
  assert.equal(result.scheduleCount, 0);
  assert.equal(result.createdCount, 0);
  assert.equal(result.refreshedCount, 0);
  assert.equal(result.skippedCount, 0);
  assert.equal(
    db.docs.has("users/userA/dailyPlans/2026-06-12_fridaySchedule"),
    false,
  );
}

async function assertExistingCalculatedPlansAreNotOverwritten() {
  const seed = baseSeed();
  seed["users/userA/dailyPlans/2026-05-31_scheduleA"] = {
    dailyPlanId: "2026-05-31_scheduleA",
    scheduleId: "scheduleA",
    planDate: "2026-05-31",
    planStatus: "CALCULATED",
    calculationTime: toTimestamp("2026-05-30T19:20:00.000Z"),
    sourceScheduleUpdatedAt: toTimestamp("2026-05-01T00:00:00.000Z"),
    createdAt: toTimestamp("2026-05-30T18:00:00.000Z"),
    updatedAt: toTimestamp("2026-05-30T18:00:00.000Z"),
  };
  const db = new FakeDb(seed);

  const result = await scheduler.createPendingDailyPlansForToday({
    db,
    now: new Date("2026-05-30T19:00:00.000Z"),
  });

  const plan = db.docs.get("users/userA/dailyPlans/2026-05-31_scheduleA");
  assert.equal(result.createdCount, 0);
  assert.equal(result.refreshedCount, 0);
  assert.equal(result.skippedCount, 1);
  assert.equal(plan.planStatus, "CALCULATED");
}

async function assertExistingPlanIsRefreshedWhenScheduleChanged() {
  const seed = baseSeed();
  seed["users/userA/schedules/scheduleA"] = {
    ...seed["users/userA/schedules/scheduleA"],
    title: "Updated Early Class",
    targetArrivalTime: "07:10",
    updatedAt: toTimestamp("2026-05-30T10:00:00.000Z"),
  };
  seed["users/userA/dailyPlans/2026-05-31_scheduleA"] = {
    dailyPlanId: "2026-05-31_scheduleA",
    scheduleId: "scheduleA",
    planDate: "2026-05-31",
    title: "Early Class",
    targetArrivalTime: "06:50",
    planStatus: "CALCULATED",
    departedAt: toTimestamp("2026-05-31T00:00:00.000Z"),
    calculationTime: toTimestamp("2026-05-30T19:20:00.000Z"),
    sourceScheduleUpdatedAt: toTimestamp("2026-05-01T00:00:00.000Z"),
    createdAt: toTimestamp("2026-05-30T18:00:00.000Z"),
    updatedAt: toTimestamp("2026-05-30T18:00:00.000Z"),
  };
  const db = new FakeDb(seed);

  const result = await scheduler.createPendingDailyPlansForToday({
    db,
    now: new Date("2026-05-30T19:00:00.000Z"),
  });

  const plan = db.docs.get("users/userA/dailyPlans/2026-05-31_scheduleA");
  assert.equal(result.createdCount, 0);
  assert.equal(result.refreshedCount, 1);
  assert.equal(result.skippedCount, 0);
  assert.equal(plan.title, "Updated Early Class");
  assert.equal(plan.targetArrivalTime, "07:10");
  assert.equal(plan.planStatus, "PENDING");
  assert.equal(plan.departedAt.toDate().toISOString(), "2026-05-31T00:00:00.000Z");
  assert.equal(plan.createdAt.toDate().toISOString(), "2026-05-30T18:00:00.000Z");
  assert.equal(plan.sourceScheduleUpdatedAt.toDate().toISOString(), "2026-05-30T10:00:00.000Z");
  assert.equal(plan.baseDepartureTime.toDate().toISOString(), "2026-05-30T20:50:00.000Z");
  assert.equal(plan.baseAlarmTime.toDate().toISOString(), "2026-05-30T20:10:00.000Z");
  assert.equal(plan.calculationTime.toDate().toISOString(), "2026-05-30T19:40:00.000Z");
}

async function assertDuePendingPlansOnlyAreFinalized() {
  const seed = baseSeed();
  seed["users/userA/dailyPlans/2026-05-31_scheduleDue"] = {
    dailyPlanId: "2026-05-31_scheduleDue",
    scheduleId: "scheduleDue",
    planDate: "2026-05-31",
    planStatus: "PENDING",
    calculationTime: toTimestamp("2026-05-30T22:25:00.000Z"),
  };
  seed["users/userA/dailyPlans/2026-05-31_scheduleFuture"] = {
    dailyPlanId: "2026-05-31_scheduleFuture",
    scheduleId: "scheduleFuture",
    planDate: "2026-05-31",
    planStatus: "PENDING",
    calculationTime: toTimestamp("2026-05-30T22:50:00.000Z"),
  };
  seed["users/userA/dailyPlans/2026-05-31_scheduleDone"] = {
    dailyPlanId: "2026-05-31_scheduleDone",
    scheduleId: "scheduleDone",
    planDate: "2026-05-31",
    planStatus: "CALCULATED",
    calculationTime: toTimestamp("2026-05-30T22:20:00.000Z"),
  };
  const db = new FakeDb(seed);
  const originalCalculate = calculator.calculateAndUpsertDailyPlan;
  const calls = [];
  calculator.calculateAndUpsertDailyPlan = async (input) => {
    calls.push(input);
    return {
      dailyPlanId: `${input.planDate}_${input.scheduleId}`,
      plan: { planStatus: "CALCULATED" },
    };
  };

  try {
    const result = await scheduler.calculateDuePendingDailyPlans({
      db,
      weatherServiceKey: "test-key",
      now: new Date("2026-05-30T22:37:00.000Z"),
    });

    assert.equal(result.processedCount, 1);
    assert.equal(result.failedCount, 0);
    assert.deepEqual(
      calls.map((call) => ({
        userId: call.userId,
        scheduleId: call.scheduleId,
        planDate: call.planDate,
        weatherServiceKey: call.weatherServiceKey,
      })),
      [
        {
          userId: "userA",
          scheduleId: "scheduleDue",
          planDate: "2026-05-31",
          weatherServiceKey: "test-key",
        },
      ],
    );
  } finally {
    calculator.calculateAndUpsertDailyPlan = originalCalculate;
  }
}

async function assertOldDailyPlansCleanupDeletesAtMostOneHundred() {
  const seed = baseSeed();
  for (let i = 0; i < 105; i++) {
    const day = String((i % 28) + 1).padStart(2, "0");
    seed[`users/userA/dailyPlans/old_${String(i).padStart(3, "0")}`] = {
      dailyPlanId: `old_${String(i).padStart(3, "0")}`,
      scheduleId: "scheduleA",
      planDate: `2025-11-${day}`,
      planStatus: "CALCULATED",
    };
  }
  seed["users/userA/dailyPlans/cutoff_day"] = {
    dailyPlanId: "cutoff_day",
    scheduleId: "scheduleA",
    planDate: "2025-12-05",
    planStatus: "CALCULATED",
  };
  seed["users/userA/dailyPlans/recent"] = {
    dailyPlanId: "recent",
    scheduleId: "scheduleA",
    planDate: "2026-01-01",
    planStatus: "CALCULATED",
  };
  const db = new FakeDb(seed);

  const result = await scheduler.cleanupOldDailyPlans({
    db,
    now: new Date("2026-06-04T19:00:00.000Z"),
  });

  assert.equal(result.cutoffDate, "2025-12-05");
  assert.equal(result.checkedCount, 100);
  assert.equal(result.deletedCount, 100);
  assert.equal(result.failedCount, 0);
  assert.equal(db.writes.filter((write) => write.type === "delete").length, 100);
  assert.equal(db.docs.has("users/userA/dailyPlans/cutoff_day"), true);
  assert.equal(db.docs.has("users/userA/dailyPlans/recent"), true);
  assert.equal(
    [...db.docs.values()].filter((data) => String(data.planDate).startsWith("2025-11")).length,
    5,
  );
}

async function assertCleanupCutoffClampsShortMonths() {
  assert.equal(
    scheduler.resolveDailyPlanCleanupCutoffDate(
      new Date("2026-08-30T19:00:00.000Z"),
    ),
    "2026-02-28",
  );
}

async function assertImpossibleFinalCalculationMarksFailed() {
  const seed = baseSeed();
  seed["users/userA/dailyPlans/2026-05-31_scheduleDue"] = {
    dailyPlanId: "2026-05-31_scheduleDue",
    scheduleId: "scheduleDue",
    planDate: "2026-05-31",
    planStatus: "PENDING",
    calculationTime: toTimestamp("2026-05-30T22:25:00.000Z"),
  };
  const db = new FakeDb(seed);
  const originalCalculate = calculator.calculateAndUpsertDailyPlan;
  calculator.calculateAndUpsertDailyPlan = async () => {
    throw new Error("schedule missing");
  };

  try {
    const result = await scheduler.calculateDuePendingDailyPlans({
      db,
      weatherServiceKey: "test-key",
      now: new Date("2026-05-30T22:37:00.000Z"),
    });

    const plan = db.docs.get("users/userA/dailyPlans/2026-05-31_scheduleDue");
    assert.equal(result.processedCount, 0);
    assert.equal(result.failedCount, 1);
    assert.equal(plan.planStatus, "FAILED");
    assert.equal(plan.failureReason, "schedule missing");
  } finally {
    calculator.calculateAndUpsertDailyPlan = originalCalculate;
  }
}

async function assertTodayScheduleWriteRecalculatesTodayPlan() {
  const originalCalculate = calculator.calculateAndUpsertDailyPlan;
  const calls = [];
  calculator.calculateAndUpsertDailyPlan = async (input) => {
    calls.push(input);
    return {
      dailyPlanId: `${input.planDate}_${input.scheduleId}`,
      plan: { planStatus: "CALCULATED" },
    };
  };

  try {
    const result = await scheduler.recalculateTodayDailyPlanForScheduleWrite({
      userId: "userA",
      scheduleId: "scheduleA",
      before: {
        title: "Early Class",
        dayOfWeek: 7,
        classTime: "07:00",
        targetArrivalTime: "06:55",
        startPlaceName: "Home",
        startAddress: "Home address",
        destinationName: "School",
        destinationAddress: "School address",
        transportMode: "BUS",
        isActive: true,
      },
      after: {
        title: "Early Class",
        dayOfWeek: 7,
        classTime: "08:00",
        targetArrivalTime: "07:55",
        startPlaceName: "Home",
        startAddress: "Home address",
        destinationName: "School",
        destinationAddress: "School address",
        transportMode: "BUS",
        isActive: true,
      },
      weatherServiceKey: "test-key",
      now: new Date("2026-05-30T19:00:00.000Z"),
    });

    assert.equal(result.recalculated, true);
    assert.equal(result.reason, "recalculated");
    assert.deepEqual(
      calls.map((call) => ({
        userId: call.userId,
        scheduleId: call.scheduleId,
        planDate: call.planDate,
        weatherServiceKey: call.weatherServiceKey,
      })),
      [
        {
          userId: "userA",
          scheduleId: "scheduleA",
          planDate: "2026-05-31",
          weatherServiceKey: "test-key",
        },
      ],
    );
  } finally {
    calculator.calculateAndUpsertDailyPlan = originalCalculate;
  }
}

async function assertFutureScheduleWriteIsIgnored() {
  const originalCalculate = calculator.calculateAndUpsertDailyPlan;
  const calls = [];
  calculator.calculateAndUpsertDailyPlan = async (input) => {
    calls.push(input);
    return {
      dailyPlanId: `${input.planDate}_${input.scheduleId}`,
      plan: { planStatus: "CALCULATED" },
    };
  };

  try {
    const result = await scheduler.recalculateTodayDailyPlanForScheduleWrite({
      userId: "userA",
      scheduleId: "scheduleWrongDay",
      before: {
        title: "Wrong Day",
        dayOfWeek: 1,
        classTime: "09:00",
        targetArrivalTime: "08:55",
        startPlaceName: "Home",
        startAddress: "Home address",
        destinationName: "School",
        destinationAddress: "School address",
        transportMode: "BUS",
        isActive: true,
      },
      after: {
        title: "Wrong Day",
        dayOfWeek: 1,
        classTime: "10:00",
        targetArrivalTime: "09:55",
        startPlaceName: "Home",
        startAddress: "Home address",
        destinationName: "School",
        destinationAddress: "School address",
        transportMode: "BUS",
        isActive: true,
      },
      weatherServiceKey: "test-key",
      now: new Date("2026-05-30T19:00:00.000Z"),
    });

    assert.equal(result.recalculated, false);
    assert.equal(result.reason, "not_today");
    assert.equal(calls.length, 0);
  } finally {
    calculator.calculateAndUpsertDailyPlan = originalCalculate;
  }
}

async function assertCacheOnlyScheduleWriteIsIgnored() {
  const originalCalculate = calculator.calculateAndUpsertDailyPlan;
  const calls = [];
  calculator.calculateAndUpsertDailyPlan = async (input) => {
    calls.push(input);
    return {
      dailyPlanId: `${input.planDate}_${input.scheduleId}`,
      plan: { planStatus: "CALCULATED" },
    };
  };

  try {
    const result = await scheduler.recalculateTodayDailyPlanForScheduleWrite({
      userId: "userA",
      scheduleId: "scheduleA",
      before: {
        title: "Early Class",
        dayOfWeek: 7,
        classTime: "07:00",
        targetArrivalTime: "06:55",
        startPlaceName: "Home",
        startAddress: "Home address",
        destinationName: "School",
        destinationAddress: "School address",
        transportMode: "BUS",
        isActive: true,
      },
      after: {
        title: "Early Class",
        dayOfWeek: 7,
        classTime: "07:00",
        targetArrivalTime: "06:55",
        startPlaceName: "Home",
        startAddress: "Home address",
        startNx: 98,
        startNy: 76,
        destinationName: "School",
        destinationAddress: "School address",
        transportMode: "BUS",
        isActive: true,
      },
      weatherServiceKey: "test-key",
      now: new Date("2026-05-30T19:00:00.000Z"),
    });

    assert.equal(result.recalculated, false);
    assert.equal(result.reason, "no_relevant_change");
    assert.equal(calls.length, 0);
  } finally {
    calculator.calculateAndUpsertDailyPlan = originalCalculate;
  }
}

async function main() {
  await assertPendingPlansAreCreatedForTodayOnly();
  await assertFridayPlanIsNotCreatedWhenFridayScheduleWasDisabledOnTuesday();
  await assertExistingCalculatedPlansAreNotOverwritten();
  await assertExistingPlanIsRefreshedWhenScheduleChanged();
  await assertDuePendingPlansOnlyAreFinalized();
  await assertImpossibleFinalCalculationMarksFailed();
  await assertOldDailyPlansCleanupDeletesAtMostOneHundred();
  await assertCleanupCutoffClampsShortMonths();
  await assertTodayScheduleWriteRecalculatesTodayPlan();
  await assertFutureScheduleWriteIsIgnored();
  await assertCacheOnlyScheduleWriteIsIgnored();
  console.log("Scheduler service regression OK");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
