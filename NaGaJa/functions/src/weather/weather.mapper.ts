import { WeatherAdjustResult } from "./weather.types";

export const mapWeatherToAdjustMinutes =(
  pty: string,
  pcp?: string,
  sno?: string
): WeatherAdjustResult /*반환 타입 지정*/ =>{
  // PTY = 0: 강수 없음
  if (pty === "0") {
    return {
      weatherType: "CLEAR",
      weatherAdjustMinutes: 0,
      reason: "강수 없음",
    };
  }

  // PTY = 1: 비
  if (pty === "1") {
    const pcpValue = parsePrecipitation(pcp);

    if (pcpValue < 1) {
      return {
        weatherType: "RAIN_LIGHT",
        weatherAdjustMinutes: 3,
        reason: "약한 비",
      };
    }

    if (pcpValue < 5) {
      return {
        weatherType: "RAIN_NORMAL",
        weatherAdjustMinutes: 5,
        reason: "보통 비",
      };
    }

    return {
      weatherType: "RAIN_HEAVY",
      weatherAdjustMinutes: 10,
      reason: "강한 비",
    };
  }

  // PTY = 2: 비/눈
  if (pty === "2") {
    const pcpValue = parsePrecipitation(pcp);
    const snoValue = parseSnow(sno);
  
    if (snoValue >= 1) {
      return {
        weatherType: "RAIN_SNOW_HEAVY",
        weatherAdjustMinutes: 15,
        reason: "비/눈 + 적설 있음",
      };
    }
  
    if (pcpValue >= 5) {
      return {
        weatherType: "RAIN_SNOW",
        weatherAdjustMinutes: 12,
        reason: "비/눈 + 강수량 많음",
      };
    }
  
    return {
      weatherType: "RAIN_SNOW",
      weatherAdjustMinutes: 10,
      reason: "비/눈",
    };
  }

  // PTY = 3: 눈
  if (pty === "3") {
    const snoValue = parseSnow(sno);

    if (snoValue < 1) {
      return {
        weatherType: "SNOW",
        weatherAdjustMinutes: 10,
        reason: "눈",
      };
    }

    return {
      weatherType: "SNOW_HEAVY",
      weatherAdjustMinutes: 15,
      reason: "많은 눈",
    };
  }

  // PTY = 4: 소나기
  if (pty === "4") {
    return {
      weatherType: "SHOWER",
      weatherAdjustMinutes: 5,
      reason: "소나기",
    };
  }

  // 알 수 없는 값이 들어왔을 때는 앱이 터지지 않게 기본값 처리
  return {
    weatherType: "CLEAR",
    weatherAdjustMinutes: 0,
    reason: "알 수 없는 날씨값 - 기본값 처리",
  };
}

function parsePrecipitation(pcp?: string): number {
  // pcp가 undefined, null, "" 이면 0을 반환  
  if (!pcp) {
    return 0;
  }
  

  if (pcp === "강수없음") {
    return 0;
  }

  return Number(pcp.replace("mm", ""));
}

function parseSnow(sno?: string): number {
  if (!sno) {
    return 0;
  }

  if (sno === "적설없음") {
    return 0;
  }

  return Number(sno.replace("cm", ""));
}