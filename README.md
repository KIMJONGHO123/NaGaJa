# 🎓 나가자 (NaGaJa)

> 팀명: [팀 이름 입력]  
> 구성원: [이름 기술]

---

## 유튜브 링크

---

## 시연 영상

---

## 개인 프로젝트 결과 보고서(영상)

---

## 📋 1. 프로젝트 개요

- **한 줄 요약**: 날씨·교통·혼잡도를 실시간 분석해 최적 기상 알람 시각을 자동 계산하는 스마트 등교 지원 앱
- **상세 설명**: Flutter + Firebase 기반 모바일 앱으로, 사용자의 시간표와 위치를 분석해 날씨·대중교통·버스 혼잡도를 반영한 출발 시각과 기상 알람을 자동 계산합니다. Wi-Fi 자동 출결 기록, 전체화면 알람, 라즈베리파이 5 물리 알람시계 연동(Wi-Fi → Firestore 실시간 구독 → 7인치 터치스크린 + GPIO 부저)을 제공합니다.

<img width="2752" height="1536" alt="스마트_동적_알람_시스템_나가자" src="https://github.com/user-attachments/assets/a49532c7-33bb-48b7-ba01-82b2c15f2c90" />

```text
├── NaGaJa/              # 소스 코드 (Flutter 앱 + Cloud Functions)
│   ├── lib/             # Flutter 모바일 앱 (프론트엔드, Dart)
│   └── functions/       # Firebase Cloud Functions (백엔드, TypeScript)
├── docs/                # 프로젝트 문서
│   ├── meeting-logs/    # 회의록
│   ├── papers/          # 논문/보고서
│   └── presentations/   # 발표 자료
├── src/
│   └── README.md        # 시스템 아키텍처 설명 및 실행 가이드
└── README.md            # 레포지토리 메인 안내 (프로젝트 개요 및 문서 링크 중심)

# 라즈베리파이 알람시계 (별도 저장소)
# https://github.com/jeje9893/NaGaJa-raspi
```

---

## 💻 2. 소스코드 및 기술 문서

본 프로젝트의 아키텍처 설계, 기술 스택, 구체적인 빌드 및 실행 방법은 아래 기술 문서(README)를 참고해 주세요.

- 👉 [소스코드 실행 방법 및 아키텍처 가이드 바로가기](src/README.md)

---

## 📅 3. 산출물 및 문서 아카이브

- 📋 [정기 회의록 폴더](docs/meeting-logs/)
- 📄 [학술대회 논문 및 보고서 폴더](docs/papers/)
- 📊 [중간/최종 발표 자료 폴더](docs/presentations/)

> 원본 파일을 제출해도 좋지만 pdf로 변환해서 업로드하면 다른 사용자가 보기 편해집니다.
