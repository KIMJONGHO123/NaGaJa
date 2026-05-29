/**
 * DailyPlan upsert target regression test.
 *
 * Run with:
 *   npm run build
 *   node scripts/test-dailyPlanUpsertTarget.mjs
 */
import assert from "assert/strict";
import admin from "firebase-admin";
import { createRequire } from "module";

const require = createRequire(import.meta.url);

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "nagaja-a6a8b";

const {
  getDailyPlanDocumentId,
  resolveDailyPlanUpsertTarget,
} = require("../lib/services/dailyPlanCalculator.js");

const planDate = "2026-05-30";
const scheduleId = "scheduleA";
const expectedDailyPlanId = `${planDate}_${scheduleId}`;

function createDailyPlansRef(seedDocs = []) {
  const makeRef = (id) => ({ id });
  const makeDoc = (doc) => ({
    id: doc.id,
    ref: makeRef(doc.id),
    get: (field) => doc.data[field],
  });

  const makeQuery = (filters) => ({
    where: (field, op, value) => makeQuery([...filters, { field, op, value }]),
    limit: () => makeQuery(filters),
    get: async () => ({
      empty: seedDocs.filter((doc) =>
        filters.every((filter) => doc.data[filter.field] === filter.value),
      ).length === 0,
      docs: seedDocs
        .filter((doc) =>
          filters.every((filter) => doc.data[filter.field] === filter.value),
        )
        .map(makeDoc),
    }),
  });

  return {
    doc: makeRef,
    where: (field, op, value) => makeQuery([{ field, op, value }]),
  };
}

async function main() {
  assert.equal(
    getDailyPlanDocumentId(planDate, scheduleId),
    expectedDailyPlanId,
  );

  const createNow = admin.firestore.Timestamp.fromMillis(2000);
  const createTarget = await resolveDailyPlanUpsertTarget({
    dailyPlansRef: createDailyPlansRef(),
    planDate,
    scheduleId,
    nowTs: createNow,
  });

  assert.equal(createTarget.mode, "create");
  assert.equal(createTarget.dailyPlanId, expectedDailyPlanId);
  assert.equal(createTarget.ref.id, expectedDailyPlanId);
  assert.equal(createTarget.createdAt.toMillis(), createNow.toMillis());

  const legacyCreatedAt = admin.firestore.Timestamp.fromMillis(1000);
  const updateTarget = await resolveDailyPlanUpsertTarget({
    dailyPlansRef: createDailyPlansRef([
      {
        id: "legacy-random-id",
        data: {
          dailyPlanId: "legacy-random-id",
          planDate,
          scheduleId,
          createdAt: legacyCreatedAt,
        },
      },
    ]),
    planDate,
    scheduleId,
    nowTs: admin.firestore.Timestamp.fromMillis(3000),
  });

  assert.equal(updateTarget.mode, "update");
  assert.equal(updateTarget.dailyPlanId, "legacy-random-id");
  assert.equal(updateTarget.ref.id, "legacy-random-id");
  assert.equal(updateTarget.createdAt.toMillis(), legacyCreatedAt.toMillis());

  console.log("DailyPlan upsert target regression OK");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
