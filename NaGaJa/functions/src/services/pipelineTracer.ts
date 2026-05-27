/** 파이프라인 주요 단계 (테스트·디버깅용, 세부 루프마다 찍지 않음) */
export type PipelineStepName =
  | "load_user"
  | "load_schedule"
  | "geocoding"
  | "schedule_update_coords"
  | "weather_api"
  | "transit_api"
  | "congestion_api"
  | "route_select"
  | "firestore_upsert";

export interface PipelineStepRecord {
  step: PipelineStepName;
  at: string;
  detail?: Record<string, unknown>;
}

export type PipelineStepSummary = Record<PipelineStepName, number>;

const STEP_NAMES: PipelineStepName[] = [
  "load_user",
  "load_schedule",
  "geocoding",
  "schedule_update_coords",
  "weather_api",
  "transit_api",
  "congestion_api",
  "route_select",
  "firestore_upsert",
];

export const emptyPipelineSummary = (): PipelineStepSummary =>
  Object.fromEntries(STEP_NAMES.map((s) => [s, 0])) as PipelineStepSummary;

export const summarizePipelineSteps = (
  steps: PipelineStepRecord[],
): PipelineStepSummary => {
  const summary = emptyPipelineSummary();
  for (const record of steps) {
    summary[record.step] += 1;
  }
  return summary;
};

/** 진행 단계 기록. tracer 미전달 시 계산기는 trace 호출을 생략 */
export class PipelineTracer {
  readonly steps: PipelineStepRecord[] = [];

  constructor(private readonly forward?: (
    step: PipelineStepName,
    detail?: Record<string, unknown>,
  ) => void) {}

  record(step: PipelineStepName, detail?: Record<string, unknown>): void {
    this.steps.push({ step, at: new Date().toISOString(), detail });
    this.forward?.(step, detail);
  }

  get summary(): PipelineStepSummary {
    return summarizePipelineSteps(this.steps);
  }
}

