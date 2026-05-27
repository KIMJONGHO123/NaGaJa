// 날씨 기능의 중심 파일
import weatherClient from './weather.client';

export const getWeather = async (
  baseDate: string,
  baseTime: string,
  nx: number,
  ny: number,
  serviceKey: string,
) => {
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
}