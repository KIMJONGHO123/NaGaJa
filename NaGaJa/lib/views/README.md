# views/

## 역할

사용자에게 보여지는 **UI 화면(Screen)과 재사용 위젯(Widget)** 을 담는 폴더입니다.

- 화면 단위로 하위 폴더를 만들어 Screen 파일과 관련 위젯을 함께 관리합니다.
- 비즈니스 로직을 직접 작성하지 않고, `providers/` 의 상태를 읽고 표시하는 역할만 합니다.
- 공통 위젯은 `views/widgets/` 폴더에 모아 재사용합니다.

## 예시 파일 구조

```
views/
├── home/
│   ├── home_screen.dart       # 메인 화면 (게이지 UI, 상태 표시)
│   └── home_widgets.dart      # 홈 전용 위젯
├── calendar/
│   └── attendance_screen.dart   # 캘린더 (출결 기록·통계)
├── settings/
│   └── settings_screen.dart   # 설정 (시간표·위치·준비시간)
└── widgets/
    ├── custom_button.dart      # 공통 버튼
    └── loading_indicator.dart  # 공통 로딩 스피너
```
