FROM node:20-slim

# Java 21 (Firebase Emulator 필수) — Debian Bookworm 기본 저장소에 없으므로 Adoptium 저장소 추가
RUN apt-get update && apt-get install -y --no-install-recommends wget gnupg ca-certificates \
 && wget -qO /usr/share/keyrings/adoptium.gpg \
    https://packages.adoptium.net/artifactory/api/gpg/key/public \
 && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] \
    https://packages.adoptium.net/artifactory/deb bookworm main" \
    > /etc/apt/sources.list.d/adoptium.list \
 && apt-get update && apt-get install -y --no-install-recommends temurin-21-jre \
 && rm -rf /var/lib/apt/lists/*

# Firebase CLI 설치
RUN npm install -g firebase-tools

WORKDIR /workspace

# Firebase 설정 파일 복사
COPY NaGaJa/firebase.json .
COPY NaGaJa/.firebaserc .
COPY NaGaJa/firestore.rules .

# Cloud Functions 의존성 설치 및 빌드
WORKDIR /workspace/functions
COPY NaGaJa/functions/package*.json ./
RUN npm ci
COPY NaGaJa/functions/src ./src
COPY NaGaJa/functions/data ./data
COPY NaGaJa/functions/tsconfig.json ./
RUN npm run build

WORKDIR /workspace

# Emulator UI(4000), Functions(5001), Firestore(8080), Auth(9099)
EXPOSE 4000 5001 8080 9099

# demo 프로젝트로 실행 — Firebase 계정 인증 불필요
CMD ["firebase", "emulators:start", \
     "--only", "auth,functions,firestore", \
     "--project", "demo-nagaja"]
