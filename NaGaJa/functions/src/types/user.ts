import type { Timestamp } from "firebase-admin/firestore";

/** `users/{userId}` 문서 */
export interface User {
  name: string;
  email: string;
  prepMinutes: number;
  defaultTravelMinutes: number;
  homeWifiSsids: string[];
  schoolWifiSsids: string[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
