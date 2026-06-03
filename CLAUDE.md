# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**NaGaJa (나가자)** — Flutter + Firebase app that calculates optimal departure times for students by combining weather, transit, and congestion data. Features a local alarm clock (Raspberry Pi) integration and Wi-Fi-based automatic attendance logging.

The Flutter project lives in the `NaGaJa/` subdirectory. All paths below are relative to `NaGaJa/` unless stated otherwise.

## Development Commands

### Flutter App

```bash
# From NaGaJa/
flutter pub get
flutter run
flutter analyze        # Dart lint (analysis_options.yaml)
flutter test
```

### Cloud Functions (TypeScript)

```bash
# From NaGaJa/functions/
npm install
npm run build                    # Compile TS → functions/lib
.\node_modules\.bin\tsc.cmd --noEmit   # Type-check only (preferred for code changes)
npm run serve                    # Build + start Firestore & Functions emulator
npm run deploy                   # Deploy to Firebase
npm run lint                     # ESLint
npm run test:pipeline            # Integration test (requires running emulator)
npm run test:alarmLogic
npm run test:dailyPlanUpsert
```

Emulator UI: `http://127.0.0.1:4000` | Functions: `127.0.0.1:5001` | Firestore: `8080`

### Firebase

```bash
firebase deploy --only functions      # Functions only
firebase deploy --only firestore:rules
```

## Architecture

### Flutter App (`NaGaJa/lib/`)

- **`main.dart`** — Entry point, Firebase init, auth routing, `IndexedStack` tab navigation
- **`models/`** — `UserModel`, `ScheduleEntry`, `DailyPlanModel` with Firestore serialization
- **`services/`** — External integrations (each a `ChangeNotifier` or plain class):
  - `settings_service.dart` — Firestore schedule & user config (ChangeNotifier, shared across screens)
  - `daily_plan_service.dart` — Calls `generateDailyPlan` Cloud Function; falls back to local calculation when backend fails
  - `alarm_service.dart` — Local alarm scheduling
  - `wifi_attendance_service.dart` — SSID detection for auto departure/arrival logging (stages 1-2 + 3-a background)
  - `background_audio_service.dart` — Silent audio loop to keep the process alive in background
- **`views/`** — `home/`, `calendar/`, `settings/`, `onboarding/`, `late_response/`, `widgets/`
- **State management**: `ChangeNotifier` + `Provider`. `IndexedStack` preserves tab state.

### Cloud Functions (`NaGaJa/functions/src/`)

- **`index.ts`** — HTTP endpoint definitions and Firebase Admin init
- **`services/dailyPlanPipeline.ts`** — Orchestrates full pipeline per schedule entry
- **`services/dailyPlanCalculator.ts`** — Core time calculation + Firestore upsert
- **`services/pipelineTracer.ts`** — Step-by-step pipeline logging
- **`utils/planTime.utils.ts`** — `baseAlarmTime`, `finalDepartureTime`, `displayColor` calculation
- **`weather/`** — External API modules:
  - `weather.service.ts` / `weather.filter.ts` / `weather.mapper.ts` — 기상청 API (PTY/PCP/SNO → time adjustment)
  - `geocoding.service.ts` — Kakao Maps address → coordinates (cached on schedule after first call)
  - `transit/` — TMAP Public Transport API (up to 10 route candidates)
  - `congestion/` — Bus congestion via CSV lookup (Busan data)
- **`types/`** — `User`, `Schedule`, `DailyPlan` TypeScript interfaces

**`functions/lib/`** is a build artifact — never edit directly.

### Core Time Calculation

```
calculationAt      = targetArrivalTime - defaultTravelMinutes - prepMinutes - 30min
baseDepartureAt    = targetArrivalTime - defaultTravelMinutes
baseAlarmAt        = baseDepartureAt - prepMinutes

predictedTravelMinutes = mapBaseTravelMinutes + congestionAdjustMinutes + weatherAdjustMinutes
finalDepartureAt   = targetArrivalTime - predictedTravelMinutes
finalAlarmAt       = finalDepartureAt - prepMinutes

remainingMarginMinutes = (targetArrivalAt - now) - predictedTravelMinutes
displayColor: GREEN (>15min) / YELLOW (≥0) / RED (<0)
```

Weather and congestion are computed **per route at its estimated departure time**, not at current time. All route candidates are evaluated before selecting the optimal one (lowest `predictedTravelMinutes`).

### Firestore Schema (key paths)

```
users/{userId}
  prepMinutes, defaultTravelMinutes, homeWifiSsids, schoolWifiSsids

users/{userId}/schedules/{scheduleId}
  classTime, targetArrivalTime, transportMode ("BUS"|"SUBWAY"|"WALK")
  startLat, startLng, startNx, startNy, endLat, endLng  ← cached after first geocode

users/{userId}/dailyPlans/{planDate}_{scheduleId}
  finalDepartureTime, finalAlarmTime, predictedTravelMinutes
  weatherType, weatherAdjustMinutes, congestionAdjustMinutes
  displayColor, remainingMarginMinutes, fallbackUsed, planStatus
  departedAt?, arrivedAt?, actualTravelMinutes?, resultStatus?
```

Attendance judgment: **ON_TIME** if `arrivedAt ≤ classTime`; **LATE** if after; **ABSENT** if no `arrivedAt` on a past plan date. Base is `classTime` (class start), not `targetArrivalTime`.

### Cloud Function Endpoints

| Function | Role |
|----------|------|
| `generateDailyPlan` | Core — calculates and upserts daily plan |
| `getTransitData` | TMAP transit routing |
| `getWeatherData` | 기상청 weather |
| `getCongestionData` | Bus congestion |
| `createDailyPlansAtDawn` | Scheduled — nightly bulk generation (deployed, no source in repo) |
| `calculatePendingDailyPlans` | Scheduled — retry uncalculated plans (deployed, no source in repo) |

## Key Rules

- **Never edit `functions/lib/`** — it is generated by `npm run build`.
- **Never read or print `.env` values**; use `.env.example` for variable names only.
- **Never change Firestore field names** without updating `src/types/` and `src/services/` together, and confirming Flutter consumer impact.
- **Never remove fallback alarm logic** — external API failures must not eliminate the base alarm.
- **`baseTime` vs `fcstTime`**: `baseTime` is the 기상청 forecast issue time; `fcstTime` is the target forecast slot. Do not confuse them.
- Coordinates (`startLat`/`startLng`) are geocoded once and cached on the schedule. `startNx`/`startNy` grid values are computed by `grid.utils.convertToGrid` in the backend — Flutter sends only lat/lng.
- If `startNx`/`startNy` are missing, the weather step sets `fallbackUsed: true`, which hides weather/congestion cards in the Flutter home screen even if routing succeeded.
- Do not modify the calculation formulas in `planTime.utils.ts` without referencing `functions/docs/alarm-calculation-logic.md`.

## Environment Variables (`NaGaJa/functions/.env`)

- `WEATHER_SERVICE_KEY` — 기상청 API key
- `TMAP_APP_KEY` — TMAP API key
- `KAKAO_REST_API_KEY` — Kakao REST API key

Firebase project: `nagaja-a6a8b` | Region: `asia-northeast3` (Seoul)

## Important Documentation

- `NaGaJa/CLAUDE.md` — Detailed project state including completed/pending features and known issues
- `NaGaJa/AGENT.md` — Operational rules for agents (modification boundaries, doc list)
- `NaGaJa/functions/AGENT.md` — Functions-specific rules (API rules, test rules)
- `NaGaJa/functions/docs/workflow.md` — Pipeline flow detail
- `NaGaJa/functions/docs/firestore-schema.md` — Complete Firestore field reference
- `NaGaJa/functions/docs/alarm-calculation-logic.md` — Authoritative calculation formulas
- `NaGaJa/functions/docs/api-rules.md` — External API integration patterns
- `NaGaJa/functions/docs/testing-rules.md` — Test and validation rules
