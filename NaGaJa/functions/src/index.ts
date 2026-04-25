/**
 * Nagaja — Cloud Functions (TypeScript)
 *
 * 리전: asia-northeast3 (서울)
 * 초기화: admin SDK 자동 초기화
 *
 * 새 함수를 추가할 때는 이 파일 또는 src/ 하위 파일에 작성 후
 */


import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onRequest,Request } from "firebase-functions/v2/https";
import { Response } from "firebase-functions";

// import {User, Schedule, DailyPlan} from "./types";
import { createMockUsers } from "./services/userService";
import { createMockSchedules } from "./services/scheduleService";
import { createMockDailyPlans } from "./services/planService";

// 2. 전역 설정 (함수들보다 먼저 실행되어야 함)
setGlobalOptions({ region: "asia-northeast3" });

// 3. Firebase Admin SDK 초기화 및 DB 인스턴스 생성
admin.initializeApp();

// 기능 1: 사용자 생성
export const createUser = onRequest(async (req: Request, res: Response) => {
  await createMockUsers();
  res.status(200).send("Users create successfully");
});

// 기능 2: 스케줄 등록
export const createSchedule = onRequest(async (req: Request, res: Response) => {
  // 로직 작성
  await createMockSchedules((req.body.userId));
  res.status(200).send("Schedule create successfully");
});

// 기능 3: 일일 플랜 생성
export const generateDailyPlan = onRequest(async (req: Request, res: Response) => {
  // 로직 작성
  await createMockDailyPlans((req.body.userId));
  res.status(200).send("DailyPlan create successfully");
});


