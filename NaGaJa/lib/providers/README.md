# providers/

## 역할

앱의 전역 상태(State) 를 관리하는 폴더입니다.

- Flutter의 `provider` 패키지(또는 Riverpod)를 사용해 상태를 보관·변경합니다.
- `services/` 를 호출해 데이터를 가져온 뒤, UI(`views/`)가 `watch` 할 수 있는
  형태로 가공하여 제공합니다.
- Provider 클래스는 `ChangeNotifier`를 상속하고, 상태가 바뀌면 `notifyListeners()`를 호출합니다.

## 예시 파일 구조

```
providers/
├── app_provider.dart          # 앱 전체 공통 상태 (로딩, 에러 등)
├── auth_provider.dart         # 사용자 인증 상태
├── attendance_provider.dart   # 출결 데이터 상태

```
