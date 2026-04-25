import * as admin from "firebase-admin";
import { User } from "../types";
import { Timestamp } from "firebase-admin/firestore";

/**
 * 목업 사용자 데이터 여러 개 생성
 */
export const createMockUsers = async () => {
  const db = admin.firestore();

  const mockUsers: User[] = [
    {
      name: "홍길동",
      email: "hong@test.com",
      prepMinutes: 20,
      defaultTravelMinutes: 30,
      homeWifiSsids: ["HOME_WIFI"],
      schoolWifiSsids: ["SCHOOL_WIFI"],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
    {
      name: "김철수",
      email: "kim@test.com",
      prepMinutes: 15,
      defaultTravelMinutes: 25,
      homeWifiSsids: ["HOME_WIFI_2"],
      schoolWifiSsids: ["SCHOOL_WIFI_2"],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
  ];

  for (const user of mockUsers) {
    const userRef = db.collection("users").doc(); // userRef는 users 컬렉션의 문서를 가리키는 참조 객체가 들어간다.
    const userId = userRef.id; // userRef.id는 users 컬렉션의 문서의 ID를 가리킨다.

    await userRef.set({ ...user, userId: userId }); // userRef.set()는 users 컬렉션의 문서를 생성하고 데이터를 저장한다다.
  }
};