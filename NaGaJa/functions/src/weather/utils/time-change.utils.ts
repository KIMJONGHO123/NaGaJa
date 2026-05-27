// functions/src/utils/time.util.ts

/**
 * 혼잡도 데이터 조회용 시간 변환 함수
 * 
 * 기준:
 * 00분 ~ 14분 → 해당 정시
 * 15분 ~ 44분 → 30분
 * 45분 ~ 59분 → 다음 정시
 *
 * 예:
 * 08:05 → 0800
 * 08:22 → 0830
 * 08:41 → 0830
 * 07:58 → 0800
 */
export function getCongestionTimeSlot(date: Date): string {
  const hour = date.getHours();
  const minute = date.getMinutes();

  let targetHour = hour;
  let targetMinute = 0;

  if (minute >= 0 && minute <= 14) {
    targetMinute = 0;
  } else if (minute >= 15 && minute <= 44) {
    targetMinute = 30;
  } else {
    targetHour = hour + 1;
    targetMinute = 0;
  }

  return (
    String(targetHour).padStart(2, "0") +
    String(targetMinute).padStart(2, "0")
  );
}

/**
 * 날씨 API fcstTime 조회용 시간 변환 함수
 *
 * 기상청 단기예보의 fcstTime은 보통 정시 단위로 제공된다.
 * 그래서 0830 같은 값을 만들지 않고,
 * 해당 정시 또는 다음 정시로만 맞춘다.
 *
 * 기준:
 * 00분 ~ 29분 → 해당 정시
 * 30분 ~ 59분 → 다음 정시
 *
 * 예:
 * 08:05 → 0800
 * 08:22 → 0800
 * 08:41 → 0900
 * 07:58 → 0800
 */
/**
 * 기상청 단기예보 baseTime — calculationAt 이전 최근 발표 시각
 * 발표: 0200, 0500, 0800, 1100, 1400, 1700, 2000, 2300
 */
export function getWeatherBaseTime(calculationAt: Date): string {
  const hour = calculationAt.getHours();
  const issuanceHours = [2, 5, 8, 11, 14, 17, 20, 23];
  let picked = 2;

  for (const h of issuanceHours) {
    if (hour >= h) {
      picked = h;
    }
  }

  return `${String(picked).padStart(2, "0")}00`;
}

export function getWeatherFcstTime(date: Date): string {
  const hour = date.getHours();
  const minute = date.getMinutes();

  let targetHour = hour;

  if (minute >= 30) {
    targetHour = hour + 1;
  }

  return String(targetHour).padStart(2, "0") + "00";
}