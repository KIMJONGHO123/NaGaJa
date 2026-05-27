import type { TransitItinerary, TransitLeg, TransitRoutesResponse } from "./transit.types";

const BUS_MODES = new Set(["BUS", "EXPRESSBUS"]);

/**
 * TMAP route 문자열에서 버스 노선번호 추출 (예: "간선:400" → "400", "100-1" 유지)
 */
export const parseBusRouteNo = (routeLabel: string | undefined): string | null => {
  if (!routeLabel?.trim()) {
    return null;
  }

  const trimmed = routeLabel.trim();
  const colonIndex = trimmed.lastIndexOf(":");
  if (colonIndex >= 0) {
    const parsed = trimmed.slice(colonIndex + 1).trim();
    return parsed.length > 0 ? parsed : null;
  }

  return trimmed;
};

/**
 * itinerary legs 중 버스 구간의 노선번호 (가장 긴 버스 구간 우선)
 */
export const extractBusRouteNoFromItinerary = (
  itinerary: TransitItinerary,
): string | null => {
  const legs = itinerary.legs ?? [];
  let bestRoute: string | null = null;
  let bestSectionTime = -1;

  for (const leg of legs) {
    if (!isBusLeg(leg)) {
      continue;
    }

    const routeNo = parseBusRouteNo(leg.route);
    if (!routeNo) {
      continue;
    }

    const sectionTime = leg.sectionTime ?? 0;
    if (sectionTime >= bestSectionTime) {
      bestSectionTime = sectionTime;
      bestRoute = routeNo;
    }
  }

  return bestRoute;
};

export const isBusItinerary = (itinerary: TransitItinerary): boolean => {
  const pathType = itinerary.pathType;
  if (pathType === 2 || pathType === 3 || pathType === 4) {
    return true;
  }

  return (itinerary.legs ?? []).some((leg) => isBusLeg(leg));
};

const isBusLeg = (leg: TransitLeg): boolean =>
  BUS_MODES.has((leg.mode ?? "").toUpperCase());

export const getItinerariesFromResponse = (
  response: TransitRoutesResponse,
): TransitItinerary[] => response.metaData?.plan?.itineraries ?? [];
