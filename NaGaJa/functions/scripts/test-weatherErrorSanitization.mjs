import assert from "node:assert/strict";

const weatherClientModule = await import("../lib/weather/weather.client.js");
const { getWeather } = await import("../lib/weather/weather.service.js");

const weatherClient = weatherClientModule.default.default;
const originalGet = weatherClient.get;
const secret = "SECRET_WEATHER_KEY_SHOULD_NOT_APPEAR";

try {
  weatherClient.get = async () => {
    const error = new Error("connect failed");
    error.code = "ECONNREFUSED";
    error.config = {
      params: {
        serviceKey: secret,
      },
    };
    throw error;
  };

  await assert.rejects(
    () => getWeather("20260530", "0500", 60, 127, secret),
    (error) => {
      assert.ok(error instanceof Error);
      assert.match(error.message, /Weather API request failed/);
      assert.doesNotMatch(error.message, new RegExp(secret));
      assert.equal("config" in error, false);
      return true;
    },
  );
} finally {
  weatherClient.get = originalGet;
}

console.log("weather error sanitization test passed");
