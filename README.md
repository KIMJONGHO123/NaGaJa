# 나가자 (Nagaja) 세팅 가이드

Flutter + Firebase 기반 스마트 알람 · 출결 관리 앱 초기 세팅 문서입니다.

---

## 프로젝트 구조

```text
NaGaJa/
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── views/
│   ├── services/
│   └── providers/
├── functions/
│   └── src/index.ts
├── android/
├── ios/
├── .gitignore
├── .gitattributes
```

---

## 필수 설치

- Flutter SDK (3.x 이상)
- Android Studio (Android SDK, cmdline-tools 포함)
- Node.js (20 LTS 권장)
- Firebase CLI
- FlutterFire CLI

설치 명령어:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

> Windows는 Flutter plugin 빌드를 위해 개발자 모드(Developer Mode) ON이 필요합니다.

### Android Studio가 필요한 이유

- Android 에뮬레이터(AVD) 실행
- Android SDK / Build-Tools / Platform-Tools 설치
- `flutter doctor --android-licenses` 및 Android 빌드 환경 구성

설치 후 확인 명령:

```bash
flutter doctor
```

`[√] Android toolchain` 이 떠야 Android 개발/배포 준비가 완료됩니다.

---

## 처음 클론 후 실행 순서

### 1) 프로젝트 받기

```bash
git clone <repository-url>
cd NaGaJa
```

### 2) 패키지 설치

```bash
flutter pub get
```

### 3) Firebase 연결

```bash
firebase login
dart pub global run flutterfire_cli:flutterfire configure --platforms=android,ios
```

생성/배치 파일:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

> iOS plist 자동 생성이 누락되면 Firebase Console에서 직접 다운로드해 `ios/Runner/GoogleService-Info.plist`로 복사합니다.

### 4) 앱 실행

```bash
flutter devices
flutter emulators --launch Pixel_7   # 필요 시
flutter run
```

---

## Cloud Functions

```bash
cd functions
npm install
npm run build
```

### 로컬 에뮬레이터 테스트 (처음 1회)

처음 한 번은 프로젝트 루트(`NaGaJa`)에서 Emulator 초기화를 해야 합니다.

```bash
firebase init emulators
```

권장 선택:

- `Use an existing project` -> `nagaja-a6a8b`
- Emulator: `Authentication`, `Functions`, `Firestore`
- 포트는 기본값 사용

`firebase.json`에 아래 설정이 있어야 Functions Emulator가 정상 시작됩니다:

```json
"functions": {
  "source": "functions"
}
```

초기화 후 실행:

```bash
cd functions
npm run serve
```

정상 동작 확인:

- Emulator UI: `http://127.0.0.1:4000`
- Functions Emulator: `127.0.0.1:5001`

종료:

- 실행 터미널에서 `Ctrl + C`

### 배포

```bash
cd functions
npm run deploy
```

> `functions/package.json`은 Node 20 기준입니다. 로컬 Node가 22면 경고가 뜰 수 있으나, 가능하면 Node 20 사용을 권장합니다.

---

## iOS 관련

- iOS 빌드/배포는 macOS + Xcode에서만 가능합니다.

```bash
cd ios
pod install
open Runner.xcworkspace
```

---

## 보안/커밋 정책

다음 파일은 커밋하지 않습니다:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `serviceAccountKey.json`
- `.env*`

`.gitignore` 정책을 따르며, 팀원은 각자 Firebase 연결 단계를 수행해야 합니다.
특히 `google-services.json`, `GoogleService-Info.plist`는 Git에 포함되지 않으므로 팀원별 `flutterfire configure` 실행이 필수입니다.
