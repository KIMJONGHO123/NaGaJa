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
  startLat?: number; // 처음에는 없어도 되는 값
  startLng?: number; // 처음에는 없어도 되는 값
  startNx?: number; // 처음에는 없어도 되는 값
  startNy?: number; // 처음에는 없어도 되는 값
  endLat?: number; // 처음에는 없어도 되는 값
  endLng?: number; // 처음에는 없어도 되는 값
  endNx?: number; // 처음에는 없어도 되는 값
  endNy?: number; // 처음에는 없어도 되는 값
  destinationName: string;
  destinationAddress: string;
  transportMode: TransportMode;
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
