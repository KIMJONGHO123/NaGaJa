import assert from "node:assert/strict";

process.env.TZ = "UTC";

const {
  combinePlanDateAndTime,
  formatBaseDate,
  formatPlanDateKst,
} = await import("../lib/utils/planTime.utils.js");

const beforeKstMorning = new Date("2026-05-28T23:30:00.000Z");
assert.equal(
  formatPlanDateKst(beforeKstMorning),
  "2026-05-29",
  "formatPlanDateKst should return the KST date, not the UTC date",
);
assert.equal(
  formatBaseDate(beforeKstMorning),
  "20260529",
  "formatBaseDate should return the KST base date for weather queries",
);

const kstTargetArrival = combinePlanDateAndTime("2026-05-29", "09:00");
assert.equal(
  kstTargetArrival.toISOString(),
  "2026-05-29T00:00:00.000Z",
  "combinePlanDateAndTime should interpret planDate + HH:mm as KST wall time",
);

console.log("planTime KST tests passed");
