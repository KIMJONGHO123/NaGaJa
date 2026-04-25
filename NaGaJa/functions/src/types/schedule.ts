import type { Timestamp } from "firebase-admin/firestore";

export type TransportMode = "BUS" | "WALK" | "SUBWAY" | string;

/** `users/{userId}/schedules/{scheduleId}` 문서 */
export interface Schedule {
  title: string;
  dayOfWeek: number;
  classTime: string;
  targetArrivalTime: string;
  startPlaceName: string;
  startAddress: string;
  destinationName: string;
  destinationAddress: string;
  transportMode: TransportMode;
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
