// 실제 날씨 api 호출 담당
import axios from 'axios';

const weatherClient = axios.create({
  baseURL: 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0',
});

export default weatherClient;