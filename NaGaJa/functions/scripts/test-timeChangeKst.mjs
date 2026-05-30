import assert from "node:assert/strict";

process.env.TZ = "UTC";

const {
  getCongestionTimeSlot,
  getWeatherBaseDateTime,
  getWeatherBaseTime,
  getWeatherForecastDateTime,
  getWeatherFcstTime,
} = await import("../lib/weather/utils/time-change.utils.js");
const { combinePlanDateAndTime } = await import(
  "../lib/utils/planTime.utils.js"
);
const { selectWeatherValuesByTime } = await import(
  "../lib/weather/weather.filter.js"
);

const kstDate = (time) => combinePlanDateAndTime("2026-05-29", time);

const cases = [
  { time: "08:05", congestion: "0800", weather: "0800" },
  { time: "08:22", congestion: "0830", weather: "0800" },
  { time: "08:41", congestion: "0830", weather: "0900" },
  { time: "07:58", congestion: "0800", weather: "0800" },
];

for (const item of cases) {
  assert.equal(
    getCongestionTimeSlot(kstDate(item.time)),
    item.congestion,
    `congestion slot for ${item.time} KST`,
  );
  assert.equal(
    getWeatherFcstTime(kstDate(item.time)),
    item.weather,
    `weather fcstTime for ${item.time} KST`,
  );
}

assert.equal(
  getWeatherBaseTime(kstDate("07:00")),
  "0500",
  "weather baseTime at 07:00 KST should use latest 05:00 issuance",
);
assert.deepEqual(
  getWeatherBaseDateTime(kstDate("01:30")),
  { baseDate: "20260528", baseTime: "2300" },
  "weather base date should roll back before the 02:00 KST issuance",
);
assert.deepEqual(
  getWeatherForecastDateTime(kstDate("23:58")),
  { fcstDate: "20260530", fcstTime: "0000" },
  "weather forecast date should roll forward when rounded past midnight",
);

const { fcstDate, fcstTime } = getWeatherForecastDateTime(kstDate("08:41"));
const selected = selectWeatherValuesByTime(
  [
    {
      baseDate: fcstDate,
      baseTime: "0500",
      category: "PTY",
      fcstDate,
      fcstTime: "0800",
      fcstValue: "0",
      nx: 60,
      ny: 127,
    },
    {
      baseDate: fcstDate,
      baseTime: "0500",
      category: "PTY",
      fcstDate,
      fcstTime,
      fcstValue: "1",
      nx: 60,
      ny: 127,
    },
    {
      baseDate: fcstDate,
      baseTime: "0500",
      category: "PCP",
      fcstDate,
      fcstTime,
      fcstValue: "5mm",
      nx: 60,
      ny: 127,
    },
    {
      baseDate: fcstDate,
      baseTime: "0500",
      category: "SNO",
      fcstDate,
      fcstTime,
      fcstValue: "0",
      nx: 60,
      ny: 127,
    },
  ],
  fcstDate,
  fcstTime,
);

assert.deepEqual(
  selected,
  {
    pty: "1",
    pcp: "5mm",
    sno: "0",
    fcstDate,
    fcstTime: "0900",
  },
  "weather lookup should select the forecast matching the KST-derived fcstTime",
);

console.log("time-change KST and weather lookup tests passed");
