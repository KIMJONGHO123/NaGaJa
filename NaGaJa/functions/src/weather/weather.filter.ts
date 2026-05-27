import {
    SelectedWeatherValues,
    WeatherForecastItem,
  } from "./weather.types";
  
  /**
   * 특정 예보 날짜와 시간에 해당하는 PTY, PCP, SNO 값을 추출한다.
   */
  export const selectWeatherValuesByTime = (
    items: WeatherForecastItem[],
    targetFcstDate: string,
    targetFcstTime: string
  ): SelectedWeatherValues => {
    // 1. 원하는 날짜와 시간의 예보 데이터만 필터링
    const targetItems = items.filter(
      (item) =>
        item.fcstDate === targetFcstDate &&
        item.fcstTime === targetFcstTime
    );

    // 2. 강수 형태 PTY 찾기
    const ptyItem = targetItems.find((item) => item.category === "PTY");
  
    // 3. 강수량 PCP 찾기
    const pcpItem = targetItems.find((item) => item.category === "PCP");
  
    // 4. 적설량 SNO 찾기
    const snoItem = targetItems.find((item) => item.category === "SNO");
  
    // 5. SelectedWeatherValues 타입으로 반환
    return {
      pty: ptyItem?.fcstValue ?? "0",
      pcp: pcpItem?.fcstValue,
      sno: snoItem?.fcstValue,
      fcstDate: targetFcstDate,
      fcstTime: targetFcstTime,
    };
  };