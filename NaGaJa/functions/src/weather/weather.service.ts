// 날씨 기능의 중심 파일
import weatherClient from './weather.client';

type WeatherRequestError = {
    code?: unknown;
    response?: {
        status?: unknown;
    };
};

export const getWeather = async (
  baseDate: string,
  baseTime: string,
  nx: number,
  ny: number,
  serviceKey: string,
) => {
  try {
    const response = await weatherClient.get('/getVilageFcst',{
        params: {
            serviceKey,
            pageNo: 1,
            numOfRows: 1000,
            dataType: 'JSON',
            base_date: baseDate,
            base_time: baseTime,
            nx: nx,
            ny: ny,
        }
    })
    return response.data;
  } catch (error) {
    const requestError = error as WeatherRequestError;
    const code =
      typeof requestError.code === "string" ? requestError.code : "unknown";
    const status =
      typeof requestError.response?.status === "number" ||
      typeof requestError.response?.status === "string" ?
        requestError.response.status :
        "unknown";

    throw new Error(`Weather API request failed: code=${code}, status=${status}`);
  }
}
