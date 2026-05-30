import fs from "node:fs";
import path from "node:path";

const loadEnvValue = (key) => {
  if (process.env[key]) {
    return process.env[key];
  }

  const envPath = path.resolve(".env");
  if (!fs.existsSync(envPath)) {
    return undefined;
  }

  const line = fs
    .readFileSync(envPath, "utf8")
    .split(/\r?\n/)
    .find((entry) => entry.trim().startsWith(`${key}=`));
  if (!line) {
    return undefined;
  }

  return line.slice(line.indexOf("=") + 1).trim();
};

const serviceKey = loadEnvValue("WEATHER_SERVICE_KEY");
if (!serviceKey) {
  console.log("weather live test skipped: WEATHER_SERVICE_KEY is not set");
  process.exit(2);
}

const { getWeather } = await import("../lib/weather/weather.service.js");
const { getWeatherBaseDateTime } = await import(
  "../lib/weather/utils/time-change.utils.js"
);

const now = new Date();
const { baseDate, baseTime } = getWeatherBaseDateTime(now);
let response;
try {
  response = await getWeather(baseDate, baseTime, 60, 127, serviceKey);
} catch (error) {
  if (error instanceof Error) {
    throw error;
  }
  throw new Error("weather API request failed");
}
const resultCode = response?.response?.header?.resultCode;

if (resultCode !== "00" && resultCode !== "03") {
  throw new Error(`weather API returned resultCode ${resultCode ?? "unknown"}`);
}

console.log(
  `weather live test passed: baseDate=${baseDate}, baseTime=${baseTime}, resultCode=${resultCode}`,
);
