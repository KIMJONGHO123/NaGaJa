// WeatherResult, Weathertype 같은 타입 정의

export type WeatherType =
  | "CLEAR"
  | "RAIN_LIGHT"
  | "RAIN_NORMAL"
  | "RAIN_HEAVY"
  | "RAIN_SNOW"
  | "RAIN_SNOW_HEAVY"
  | "SNOW"
  | "SNOW_HEAVY"
  | "SHOWER";

/**
 * 기상청 날씨값을 우리 서비스의 날씨 타입과 보정시간으로 변환한 결과 타입
 */
export interface WeatherAdjustResult {
  weatherType: WeatherType;
  weatherAdjustMinutes: number;
  reason: string;
}

/**
 * 기상청 단기예보 API의 개별 예보 item 타입
 */
export interface WeatherForecastItem {
  baseDate: string;
  baseTime: string;
  category: string;
  fcstDate: string;
  fcstTime: string;
  fcstValue: string;
  nx: number;
  ny: number;
}

/**
 * 날씨 보정 계산에 필요한 PTY, PCP, SNO 값만 추출한 타입
 */
export interface SelectedWeatherValues {
  pty: string;
  pcp?: string;
  sno?: string;
  fcstDate: string;
  fcstTime: string;
}