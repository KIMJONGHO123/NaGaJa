# models/

## 역할
앱에서 사용되는 **데이터 구조(Data Class)** 를 정의하는 폴더입니다.

- Firestore 문서(Document)와 1:1로 대응되는 클래스를 여기에 작성합니다.
- `fromJson()` / `toJson()` 또는 `fromMap()` / `toMap()` 변환 메서드를 포함합니다.
- 비즈니스 로직은 넣지 않고, **순수 데이터 표현**만 담당합니다.

## 예시 파일 구조
```
models/
├── user_model.dart        # 사용자 정보
├── alarm_model.dart       # 알람 설정
└── attendance_model.dart  # 출결 기록
```
