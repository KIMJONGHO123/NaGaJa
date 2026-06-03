/**
 * TMAP 대중교통 API 호출
 */
import transitClient from "./transit.client";
import { TMAP_TRANSIT_ROUTES_PATH } from "./transit.config";
import {
  buildTransitRoutesRequest,
  formatSearchDttm,
} from "./transit.request";
import type {
  TransitRoutesCoords,
  TransitRoutesResponse,
} from "./transit.types";

export const getTransitRoutes = async (
  coords: TransitRoutesCoords,
  departureAt?: Date,
): Promise<TransitRoutesResponse> => {
  const body = buildTransitRoutesRequest({
    ...coords,
    searchDttm:
      coords.searchDttm ?? formatSearchDttm(departureAt ?? new Date()),
  });

  const response = await transitClient.post<TransitRoutesResponse>(
    TMAP_TRANSIT_ROUTES_PATH,
    body,
  );

  return response.data;
};

/** 하위 호환 alias (기존 코드 호환용) */
export const getTransitSummary = getTransitRoutes;
