# services/

## 역할

외부 시스템과의 통신 로직을 담당하는 폴더입니다.

- Firebase(Firestore, Auth, FCM), 외부 REST API(Kakao Maps, OpenWeather) 등
  모든 I/O 작업이 여기에 위치합니다.
- UI(`views/`)나 상태 관리(`providers/`)가 직접 Firebase SDK를 호출하지 않도록
  서비스 레이어로 격리합니다.
- 함수는 순수하게 데이터를 가져오거나 저장하는 역할만 합니다.

## 예시 파일 구조

```
services/
├── auth_service.dart          # Firebase Auth (로그인·로그아웃·회원가입)
├── firestore_service.dart     # Firestore CRUD 공통 래퍼
├── attendance_service.dart    # 출결 기록 읽기·쓰기
├── alarm_service.dart         # 알람: 백엔드(Cloud Functions)에 계산 요청·결과 수신만 (계산은 서버)
├── location_service.dart      # 위치 정보 조회
└── notification_service.dart  # FCM 푸시 알림 수신 처리
```
