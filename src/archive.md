# 아카이브 사이트 제출 가이드

아카이브 사이트: **`https://aswarchive.aswinfra.org`** (Forgejo 기반 Git 저장소)

---

## 1단계 — 계정 생성

1. `https://aswarchive.aswinfra.org` 접속
2. **가입하기** 클릭 → 이름·이메일·비밀번호 입력
3. 이메일 인증 링크 클릭하여 계정 활성화

---

## 2단계 — 저장소 생성

1. 로그인 후 우측 상단 **[+]** → **새 저장소**
2. 저장소 이름: `NaGaJa` (또는 팀명 기반)
3. 공개 여부 설정 후 **저장소 만들기** 클릭
4. 생성된 저장소 URL 메모: `https://aswarchive.aswinfra.org/<계정명>/NaGaJa`

---

## 3단계 — Personal Access Token 발급

비밀번호 대신 Token으로 인증합니다.

1. 우측 상단 프로필 아이콘 → **설정**
2. 좌측 메뉴 **Applications** (또는 앱·토큰)
3. **Token 이름** 입력 (예: `nagaja-push`) → **토큰 생성**
4. 생성된 토큰 값을 복사해 안전한 곳에 저장 (다시 볼 수 없음)

---

## 4단계 — git remote 추가 및 push

> **PowerShell**을 열고 저장소 루트 폴더로 이동합니다.

```powershell
cd C:\...\NaGaJa    # docker-compose.yml, README.md가 있는 폴더
```

아카이브 remote 추가:

```powershell
git remote add archive https://aswarchive.aswinfra.org/<계정명>/NaGaJa.git
```

현재 브랜치(`upload`)를 아카이브의 `main`으로 push:

```powershell
git push -u archive upload:main
```

인증 창이 뜨면:
- **Username**: 아카이브 사이트 계정명
- **Password**: 3단계에서 발급한 **Personal Access Token** 붙여넣기

---

## 5단계 — 제출 확인

아카이브 사이트 저장소 페이지에서 아래 파일들이 보이는지 확인합니다:

| 파일/폴더 | 역할 |
|-----------|------|
| `README.md` | 프로젝트 개요 및 문서 링크 |
| `Dockerfile` | Docker 이미지 빌드 설정 |
| `docker-compose.yml` | 컨테이너 실행 설정 |
| `.env.example` | 환경 변수 목록 (실제 키 없음) |
| `NaGaJa/` | Flutter 앱 + Cloud Functions 소스 |
| `src/README.md` | 아키텍처 및 실행 가이드 |
| `docs/` | 회의록·논문·발표 자료 |

---

## 이후 업데이트 push

코드나 문서를 수정한 후 다시 올릴 때:

```powershell
git add .
git commit -m "업데이트 내용 요약"
git push archive upload:main
```

---

## 문제 해결

**remote already exists 에러**
```powershell
git remote set-url archive https://aswarchive.aswinfra.org/<계정명>/NaGaJa.git
```

**인증 실패 (Authentication failed)**
- Username이 이메일이 아닌 **계정명**인지 확인
- Password 란에 비밀번호가 아닌 **Personal Access Token**을 입력했는지 확인

**push rejected (non-fast-forward)**
```powershell
git push archive upload:main --force
```
> 저장소가 비어있지 않을 때 최초 1회만 사용합니다.
