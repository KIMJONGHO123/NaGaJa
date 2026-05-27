/**
 * TMAP 대중교통 API HTTP 클라이언트
 * appKey는 요청 헤더로 전달 (SK open API 공통)
 */
import axios from "axios";
import {TMAP_TRANSIT_BASE_URL } from "./transit.config";
import { defineString } from "firebase-functions/params";

const TMAP_APP_KEY = defineString("TMAP_APP_KEY");

const transitClient = axios.create({
  baseURL: TMAP_TRANSIT_BASE_URL,
  headers: {
    Accept: "application/json",
    "Content-Type": "application/json",
    // 앱키 들어가는 자리 (헤더 appKey)
    appKey: TMAP_APP_KEY.value(),
  },
});

export default transitClient;
