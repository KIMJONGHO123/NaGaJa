# Mobile (Flutter)

Flutter 앱 소스코드는 [`../NaGaJa/`](../NaGaJa/) 디렉터리에 있습니다.

## 요구사항
- Flutter SDK 3.x 이상
- Android Studio 또는 VS Code
- 연결된 Android/iOS 기기 또는 에뮬레이터

## 빌드 및 실행
```bash
cd NaGaJa
flutter pub get
flutter run                  # 연결된 기기/에뮬레이터에서 실행
flutter build apk            # Android APK 빌드
flutter build apk --release  # 릴리즈 빌드
```

## 앱 구조
```
NaGaJa/lib/
├── main.dart               # 진입점, Firebase 초기화, 탭 네비게이션
├── models/                 # UserModel, ScheduleEntry, DailyPlanModel
├── services/               # AlarmService, WifiAttendanceService 등
└── views/                  # home, alarm, calendar, settings, onboarding
```
