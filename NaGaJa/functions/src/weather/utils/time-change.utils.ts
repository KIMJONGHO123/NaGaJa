// functions/src/utils/time.util.ts

const getKstTimeParts = (date: Date): { hour: number; minute: number } => {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Seoul",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const getPart = (type: "hour" | "minute"): number => {
    const value = parts.find((part) => part.type === type)?.value;
    if (!value) {
      throw new Error(`Failed to format KST ${type}`);
    }
    return Number(value);
  };

  return {
    hour: getPart("hour"),
    minute: getPart("minute"),
  };
};

const getKstDateParts = (date: Date): {
  year: string;
  month: string;
  day: string;
} => {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const getPart = (type: "year" | "month" | "day"): string => {
    const value = parts.find((part) => part.type === type)?.value;
    if (!value) {
      throw new Error(`Failed to format KST ${type}`);
    }
    return value;
  };

  return {
    year: getPart("year"),
    month: getPart("month"),
    day: getPart("day"),
  };
};

const formatKstBaseDate = (date: Date): string => {
  const { year, month, day } = getKstDateParts(date);
  return `${year}${month}${day}`;
};

const addMinutes = (date: Date, minutes: number): Date =>
  new Date(date.getTime() + minutes * 60_000);

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
  const { hour, minute } = getKstTimeParts(date);

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
  return getWeatherBaseDateTime(calculationAt).baseTime;
}

export function getWeatherBaseDateTime(calculationAt: Date): {
  baseDate: string;
  baseTime: string;
} {
  const { hour } = getKstTimeParts(calculationAt);
  const issuanceHours = [2, 5, 8, 11, 14, 17, 20, 23];
  let picked = 23;
  let baseDateSource = addMinutes(calculationAt, -3 * 60);

  for (const h of issuanceHours) {
    if (hour >= h) {
      picked = h;
      baseDateSource = calculationAt;
    }
  }

  return {
    baseDate: formatKstBaseDate(baseDateSource),
    baseTime: `${String(picked).padStart(2, "0")}00`,
  };
}

export function getWeatherFcstTime(date: Date): string {
  return getWeatherForecastDateTime(date).fcstTime;
}

export function getWeatherForecastDateTime(date: Date): {
  fcstDate: string;
  fcstTime: string;
} {
  const { hour, minute } = getKstTimeParts(date);

  const targetDate = minute >= 30 ? addMinutes(date, 60 - minute) : date;
  const targetHour = minute >= 30 ? getKstTimeParts(targetDate).hour : hour;

  return {
    fcstDate: formatKstBaseDate(targetDate),
    fcstTime: String(targetHour).padStart(2, "0") + "00",
  };
}
