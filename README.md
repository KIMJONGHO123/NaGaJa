# 나가자 (Nagaja)

> Flutter + Firebase 기반 스마트 알람 · 출결 관리 앱  
> Raspberry Pi 물리 알람시계와 연동되는 IoT 프로젝트입니다.

---

## 프로젝트 구조

```
nagaja/
├── lib/                        # Flutter 앱 소스
│   ├── main.dart               # 앱 진입점
│   ├── models/                 # 데이터 클래스 (Firestore 문서 구조)
│   ├── views/                  # UI 화면 & 재사용 위젯
│   ├── services/               # Firebase / 외부 API 통신 레이어
│   └── providers/              # 전역 상태 관리 (Provider)
├── functions/                  # Firebase Cloud Functions (TypeScript)
│   └── src/index.ts            # 함수 진입점 (서울 리전)
├── .gitignore                  # Git 제외 목록
├── .gitattributes              # 줄바꿈 정규화 설정
└── README.md                   # 이 문서
```

---

## 시작 전 필수 설치

| 도구            | 버전         | 설치 링크                                    |
| --------------- | ------------ | -------------------------------------------- |
| Flutter SDK     | 3.x 이상     | https://docs.flutter.dev/get-started/install |
| Dart SDK        | Flutter 내장 | (Flutter 설치 시 자동)                       |
| Node.js         | 20 LTS       | https://nodejs.org                           |
| Firebase CLI    | 최신         | `npm install -g firebase-tools`              |
| FlutterFire CLI | 최신         | `dart pub global activate flutterfire_cli`   |

---

## 처음 클론 후 실행 순서

### 1단계 — 저장소 클론

```bash
git clone https://github.com/<your-org>/nagaja.git
cd nagaja
```

### 2단계 — Flutter 패키지 설치

```bash
flutter pub get
```

### 3단계 — Firebase 프로젝트 연결

> Firebase 콘솔(https://console.firebase.google.com)에서 프로젝트를 미리 생성해 두어야 합니다.
> **이건 내가 만들어놓음**

```bash

# Firebase CLI 로그인
firebase login

# FlutterFire CLI 로 firebase_options.dart 자동 생성
flutterfire configure
```

`flutterfire configure` 를 실행하면:

- `lib/firebase_options.dart` 가 자동 생성됩니다.
- Android: `android/app/google-services.json` 배치
- iOS: `ios/Runner/GoogleService-Info.plist` 배치

> `google-services.json` 과 `GoogleService-Info.plist` 는 `.gitignore` 에 등록되어  
> Git에 올라가지 않습니다. **팀원 각자가 직접 실행**해야 합니다.

### 4단계 — 앱 실행

```bash
# 연결된 디바이스 확인
flutter devices

# 앱 실행 (디바이스 ID 지정)
flutter run -d <device-id>

# 또는 VS Code / Android Studio 의 Run 버튼 사용
```

---

## Cloud Functions 설정 & 배포

```bash
# functions 폴더로 이동
cd functions

# 의존성 설치
npm install

# TypeScript 빌드 (개발 중 실시간 감시)
npm run build:watch

# 로컬 에뮬레이터로 테스트
npm run serve

# 서울 리전으로 배포
npm run deploy
```

> **리전**: 모든 함수는 `asia-northeast3` (서울)로 배포됩니다.  
> `functions/src/index.ts` 상단의 `setGlobalOptions` 에서 변경할 수 있습니다.

---

## IDE별 설정 안내

### VS Code

1. 확장 프로그램 설치: `Flutter`, `Dart`, `Firebase`
2. `.vscode/` 폴더는 Git에 올라가지 않으므로 팀원 각자 설정합니다.
3. 실행: `F5` 또는 터미널에서 `flutter run`

### Android Studio

1. **SDK Manager** 에서 Flutter·Dart 플러그인 설치
2. `Open` → 프로젝트 루트 선택
3. `.idea/` 폴더는 Git에서 제외되어 있습니다.

### Xcode (iOS 빌드, macOS 전용)

```bash
cd ios
pod install        # CocoaPods 의존성 설치
open Runner.xcworkspace
```

> `*.xcworkspace` 를 직접 열어야 합니다. `Runner.xcodeproj` 는 사용하지 마세요.

---

## Git 브랜치 전략

| 브랜치 | 용도                                    |
| ------ | --------------------------------------- |
| `main` | 배포 가능한 안정 버전                   |
| `dev`  | 통합 개발 브랜치                        |
| `이름` | 본인 기능 개발 (ex. `feature/alarm-ui`) |

---

## 보안 주의사항

- `google-services.json`, `GoogleService-Info.plist`, `serviceAccountKey.json`,  
  `.env` 파일은 **절대 Git에 커밋하지 마세요.**
- 이 파일들은 `.gitignore` 에 이미 등록되어 있습니다.
- Firebase 보안 규칙(`firestore.rules`, `storage.rules`)은 반드시 검토 후 배포하세요.

---

## 기술 스택

| 분류      | 기술                                             |
| --------- | ------------------------------------------------ |
| 모바일 앱 | Flutter (iOS / Android)                          |
| 백엔드    | Firebase (Firestore, Auth, Cloud Functions, FCM) |
| 하드웨어  | Raspberry Pi + Python                            |
| 외부 API  | Kakao Maps, OpenWeather, 더 추가될 수도 있음     |
| 상태 관리 | Provider                                         |
| Functions | TypeScript (Node.js 20)                          |

---
