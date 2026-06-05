import * as admin from "firebase-admin";
import type { CalculateDailyPlanResult } from "./dailyPlanCalculator";
import {
  calculateAndUpsertDailyPlan,
  calculateDailyPlansForUser,
  resolveNextSchedulePlanDate,
  resolvePlanDate,
} from "./dailyPlanCalculator";
import {
  type PipelineStepName,
  type PipelineStepRecord,
  type PipelineStepSummary,
  PipelineTracer,
} from "./pipelineTracer";

export type {
  PipelineStepName,
  PipelineStepRecord,
  PipelineStepSummary,
};

export interface RunFullDailyPlanPipelineInput {
  userId: string;
  weatherServiceKey: string;
  scheduleId?: string;
  planDate?: string;
  /** 실시간 로그가 필요할 때만 (테스트·디버깅) */
  onStep?: (step: PipelineStepName, detail?: Record<string, unknown>) => void;
}

export interface RunFullDailyPlanPipelineResult {
  planDate: string;
  results: CalculateDailyPlanResult[];
  steps: PipelineStepRecord[];
  summary: PipelineStepSummary;
}

const resolvePipelinePlanDate = async (
  input: RunFullDailyPlanPipelineInput,
): Promise<string> => {
  if (input.planDate) {
    return resolvePlanDate(input.planDate);
  }

  if (!input.scheduleId) {
    return resolvePlanDate();
  }

  const scheduleSnap = await admin
    .firestore()
    .collection("users")
    .doc(input.userId)
    .collection("schedules")
    .doc(input.scheduleId)
    .get();

  if (!scheduleSnap.exists) {
    throw new Error(`Schedule ${input.scheduleId} not found`);
  }

  const dayOfWeek = Number(scheduleSnap.data()?.dayOfWeek);
  return resolveNextSchedulePlanDate(new Date(), dayOfWeek);
};

/**
 * 일일 플랜 전체 파이프라인. 진행 추적은 PipelineTracer가 담당.
 */
export const runFullDailyPlanPipeline = async (
  input: RunFullDailyPlanPipelineInput,
): Promise<RunFullDailyPlanPipelineResult> => {
  const planDate = await resolvePipelinePlanDate(input);
  const tracer = new PipelineTracer(input.onStep);

  const results = input.scheduleId
    ? [
        await calculateAndUpsertDailyPlan({
          userId: input.userId,
          scheduleId: input.scheduleId,
          planDate,
          weatherServiceKey: input.weatherServiceKey,
          tracer,
        }),
      ]
    : await calculateDailyPlansForUser(
        input.userId,
        planDate,
        input.weatherServiceKey,
        tracer,
      );

  return {
    planDate,
    results,
    steps: tracer.steps,
    summary: tracer.summary,
  };
};

/** 통합 테스트에서 기대하는 최소 호출 여부 검증 */
export const assertPipelineSteps = (
  summary: PipelineStepSummary,
  options: {
    expectTransit?: boolean;
    expectCongestion?: boolean;
    expectGeocoding?: boolean;
  } = {},
): { ok: boolean; errors: string[] } => {
  const errors: string[] = [];

  if (summary.load_user < 1) {
    errors.push("load_user가 호출되지 않았습니다.");
  }
  if (summary.load_schedule < 1) {
    errors.push("load_schedule가 호출되지 않았습니다.");
  }
  if (summary.firestore_upsert < 1) {
    errors.push("firestore_upsert가 호출되지 않았습니다.");
  }
  if (summary.weather_api < 1) {
    errors.push("weather_api가 호출되지 않았습니다.");
  }

  if (options.expectGeocoding !== false && summary.geocoding < 1) {
    errors.push("geocoding이 호출되지 않았습니다 (좌표 없는 스케줄 필요).");
  }

  if (options.expectTransit !== false && summary.transit_api < 1) {
    errors.push(
      "transit_api가 호출되지 않았습니다 (TMAP_APP_KEY·좌표 확인).",
    );
  }

  if (options.expectCongestion && summary.congestion_api < 1) {
    errors.push(
      "congestion_api가 호출되지 않았습니다 (BUS 스케줄·CSV 경로 확인).",
    );
  }

  return { ok: errors.length === 0, errors };
};
