// db에서 출발지 주소 가져와서 지도 api를 사용해서 위도,경도로 변환

import axios from "axios";
import { defineString } from "firebase-functions/params";

const kakaoRestApiKey = defineString("KAKAO_REST_API_KEY");
export const getAddress = async (
    startAddress: string
) => {

    const response = await axios.get(
        "https://dapi.kakao.com/v2/local/search/address.json",
        {
            params: {
                query: startAddress,
            },
            headers: {
                Authorization: `KakaoAK ${kakaoRestApiKey.value()}`, // 카카오 주소 검색 api 키
            },
        }
    );

    if (response.data.documents.length === 0) {
        throw new Error("주소 검색 결과 없음");
    }

    return {
        longitude: response.data.documents[0].x, //경도
        latitude: response.data.documents[0].y, //위도
    };
};


// nx,ny로 변환
