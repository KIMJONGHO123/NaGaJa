import type { WeatherForecastItem } from "./weather.types";

/** 기상청 단기예보 API 응답에서 item 배열 추출 */
export const extractWeatherForecastItems = (
  weatherResponse: unknown,
): WeatherForecastItem[] => {
  const root = weatherResponse as {
    response?: {
      header?: {
        resultCode?: string;
        resultMsg?: string;
      };
      body?: {
        items?: {
          item?: WeatherForecastItem | WeatherForecastItem[];
        };
      };
    };
  };

  const resultCode = root.response?.header?.resultCode;
  if (resultCode === "03") {
    return [];
  }
  if (resultCode && resultCode !== "00") {
    throw new Error(
      `기상청 API 오류: ${resultCode} ${root.response?.header?.resultMsg ?? ""}`,
    );
  }

  const item = root.response?.body?.items?.item;
  if (!item) {
    return [];
  }

  return Array.isArray(item) ? item : [item];
};
