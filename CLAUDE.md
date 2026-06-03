# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**NaGaJa (나가자)** — Flutter + Firebase app that calculates optimal departure times for students by combining weather, transit, and congestion data. Features a full-screen alarm, Wi-Fi-based automatic attendance logging, and Raspberry Pi integration.

The Flutter project lives in the `NaGaJa/` subdirectory. All paths below are relative to `NaGaJa/` unless stated otherwise.

## Development Commands

### Flutter App

```bash
# From NaGaJa/
flutter pub get
flutter run
flutter analyze        # Dart lint (analysis_options.yaml)
flutter test           # 22 unit tests in test/models/
```

### Cloud Functions (TypeScript)

```bash
# From NaGaJa/functions/
npm install
npm run build                         # Compile TS → functions/lib
.\node_modules\.bin\tsc.cmd --noEmit  # Type-check only (preferred for code changes)
npm run serve                         # Build + start Firestore & Functions emulator
npm run deploy                        # Deploy to Firebase
npm run lint                          # ESLint

# Tests (no external deps needed)
npm run test:alarmLogic
npm run test:dailyPlanUpsert
npm run test:planTimeKst
npm run test:timeChangeKst
npm run test:weatherError
npm run test:schedulerService

# Integration test (requires Firestore emulator)
npm run test:pipeline
```

Emulator UI: `http://127.0.0.1:4000` | Functions: `127.0.0.1:5001` | Firestore: `8080`

### Firebase

```bash
firebase deploy --only functions
firebase deploy --only firestore:rules
```

## Architecture

### Flutter App (`NaGaJa/lib/`)

- **`main.dart`** — Entry point, Firebase init, auth routing, `IndexedStack` tab navigation. Also declares the global `navigatorKey` and the alarm listener (`alarmFiredNotifier` → `AlarmScreen`).
- **`models/`** — `UserModel`, `ScheduleEntry`, `DailyPlanModel` with Firestore serialization
- **`services/`** — External integrations:
  - `settings_service.dart` — Firestore schedule & user config (ChangeNotifier, shared across screens)
  - `daily_plan_service.dart` — Calls `generateDailyPlan` Cloud Function; falls back to local calculation when backend fails
  - `alarm_service.dart` — Local alarm scheduling, `alarmFiredNotifier` (ValueNotifier), `_appInForeground` flag
  - `wifi_attendance_service.dart` — SSID detection for auto departure/arrival logging (stages 1-2 + 3-a background)
  - `background_audio_service.dart` — Silent audio loop to keep the process alive in background
- **`views/`** — `home/`, `alarm/`, `calendar/`, `settings/`, `onboarding/`, `late_response/`, `widgets/`
- **State management**: `ChangeNotifier` + `Provider`. `IndexedStack` preserves tab state.

### Alarm Feature — Multi-file Flow

The alarm involves four files working together. Non-obvious wiring:

1. **`alarm_service.dart`**: `_fireAlarm()` sets `alarmFiredNotifier.value = true` and (when backgrounded) calls `_showImmediateNotification()` with `fullScreenIntent: true`. The `_appInForeground` flag (updated from `main.dart`'s `AppLifecycleState`) controls whether the notification fires — it is suppressed in the foreground to avoid a double UI.

2. **`main.dart`**: Holds `final GlobalKey<NavigatorState> navigatorKey`. `_NagajaAppState` listens to `alarmFiredNotifier` and calls `navigatorKey.currentState?.push(AlarmScreen)`. The `_alarmScreenShowing` bool prevents duplicate pushes.

3. **`views/alarm/alarm_screen.dart`**: Full-screen alarm UI. Listens to `alarmFiredNotifier` via `_onExternalDismiss` — if the value becomes false while the screen is visible (e.g., user tapped the notification action button), it auto-pops. `PopScope(canPop: false)` blocks back gesture.

4. **Notification action button**: Must use `showsUserInterface: true` on `AndroidNotificationAction`. Without it, the action callback runs in a **separate Dart isolate**, so `AlarmService.instance` state changes do not reach the main app.

### Cloud Functions (`NaGaJa/functions/src/`)

- **`index.ts`** — HTTP endpoint definitions and Firebase Admin init
- **`services/dailyPlanPipeline.ts`** — Orchestrates full pipeline per schedule entry
- **`services/dailyPlanCalculator.ts`** — Core time calculation + Firestore upsert
- **`utils/planTime.utils.ts`** — `baseAlarmTime`, `finalDepartureTime`, `displayColor` calculation
- **`weather/`** — External API modules: 기상청, Kakao geocoding, TMAP transit, congestion CSV

**`functions/lib/`** is a build artifact — never edit directly.

### Core Time Calculation

```
predictedTravelMinutes = mapBaseTravelMinutes + congestionAdjustMinutes + weatherAdjustMinutes
finalDepartureAt   = targetArrivalTime - predictedTravelMinutes
finalAlarmAt       = finalDepartureAt - prepMinutes

remainingMarginMinutes = (targetArrivalAt - now) - predictedTravelMinutes
displayColor: GREEN (>15min) / YELLOW (≥0) / RED (<0)
```

Weather and congestion are computed **per route at its estimated departure time**. All candidates are evaluated before selecting the one with the lowest `predictedTravelMinutes`.

### Firestore Schema (key paths)

```
users/{userId}/dailyPlans/{planDate}_{scheduleId}
  finalDepartureTime, finalAlarmTime   ← Timestamp; sentinel DateTime(1970) when missing
  predictedTravelMinutes, displayColor, fallbackUsed, planStatus
  departedAt?, arrivedAt?, actualTravelMinutes?, resultStatus?
```

Attendance judgment: **ON_TIME** if `arrivedAt ≤ classTime`; **LATE** if after; **ABSENT** if no `arrivedAt` on a past plan date. Base is `classTime` (class start), not `targetArrivalTime`.

## Key Rules

- **Never edit `functions/lib/`** — generated by `npm run build`.
- **Never read or print `.env` values**; use `.env.example` for variable names only.
- **Never change Firestore field names** without updating `src/types/` and `src/services/` together, and confirming Flutter consumer impact.
- **Never remove fallback alarm logic** — external API failures must not eliminate the base alarm.
- **`baseTime` vs `fcstTime`**: `baseTime` is the 기상청 forecast issue time; `fcstTime` is the target forecast slot. Do not confuse them.
- Coordinates (`startLat`/`startLng`) are geocoded once and cached on the schedule. `startNx`/`startNy` grid values are computed by the backend — Flutter sends only lat/lng.
- If `startNx`/`startNy` are missing, the weather step sets `fallbackUsed: true`, hiding weather/congestion cards in the Flutter home screen.
- **`DailyPlanModel.finalAlarmTime` / `finalDepartureTime`** use `DateTime.fromMillisecondsSinceEpoch(0)` (year 1970) as a sentinel when the Firestore `Timestamp` field is absent. Check validity with `_isValidTime(dt)` = `dt.year >= 2000` before using these fields for scheduling or display.
- Do not modify calculation formulas in `planTime.utils.ts` without referencing `functions/docs/alarm-calculation-logic.md`.

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
