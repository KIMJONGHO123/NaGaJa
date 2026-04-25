import { Schedule } from "../types";
import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";

 //특정 사용자 하위에 목업 스케줄 데이터 생성
 
 //저장 위치:
 //users/{userId}/schedules/{scheduleId}
 

export const createMockSchedules = async (userId: string) => {
    const db = admin.firestore();
    const now = Timestamp.now();

    const mockSchedules: Omit<Schedule, "scheduleId" | "userId">[] = [
        // Omit = "이 타입에서 특정 필드 빼고 쓰겠다"
        // scheduleId, userId 없는 상태로 Schedule 배열 만들겠다
      {
        title: "자료구조",
        dayOfWeek: 1,
        classTime: "09:00",
        targetArrivalTime: "08:55",

        startPlaceName: "집",
        startAddress: "부산광역시 ...",

        destinationName: "공학관",
        destinationAddress: "공학관 주소",

        transportMode: "BUS",

        isActive: true,

        createdAt: now,
        updatedAt: now,
      },
      {
        title: "운영체제",
        dayOfWeek: 3,
        classTime: "10:30",
        targetArrivalTime: "10:25",

        startPlaceName: "집",
        startAddress: "부산광역시 해운대구 ...",

        destinationName: "정보관",
        destinationAddress: "부산대학교 정보관",

        transportMode: "SUBWAY",

        isActive: true,

        createdAt: now,
        updatedAt: now,
      },
    ];


    // users 컬렉션에 userId 문서가 있는지 확인
    const userIdRef = db.collection("users").doc(userId);
    const userIdDoc = await userIdRef.get();
    if(!userIdDoc.exists){
        throw new Error(`User ${userId} not found`);
    }

  
    // mockSchedules 배열을 순회하면서 각 스케줄을 데이터베이스에 저장
    for (const schedule of mockSchedules) {
      const scheduleRef = db
        .collection("users")
        .doc(userId)
        .collection("schedules")
        .doc();
  
      const scheduleId = scheduleRef.id;
  
      await scheduleRef.set({
        ...schedule,
        scheduleId,
        userId,
      });
    }
}