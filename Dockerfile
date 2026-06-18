FROM eclipse-temurin:21-jre-jammy

# Node.js 20 설치 (Firebase CLI 실행에 필요)
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Firebase CLI 설치
RUN npm install -g firebase-tools

WORKDIR /workspace

# Firebase 설정 파일 복사
COPY NaGaJa/firebase.json .
COPY NaGaJa/.firebaserc .
COPY NaGaJa/firestore.rules .

# 에뮬레이터 바이너리를 빌드 시간에 미리 다운로드 (컨테이너 시작 지연 방지)
RUN firebase setup:emulators:firestore --project demo-nagaja \
 && firebase setup:emulators:ui --project demo-nagaja \
 && firebase setup:emulators:storage --project demo-nagaja 2>/dev/null || true

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

# firebase-functions/params 가 .env 파일에서 파라미터 값을 읽으므로,
# 컨테이너 환경변수를 functions/.env 로 내보낸 뒤 에뮬레이터 실행
CMD ["sh", "-c", \
     "printf 'WEATHER_SERVICE_KEY=%s\\nKAKAO_REST_API_KEY=%s\\nTMAP_APP_KEY=%s\\n' \
       \"$WEATHER_SERVICE_KEY\" \"$KAKAO_REST_API_KEY\" \"$TMAP_APP_KEY\" \
       > /workspace/functions/.env \
     && firebase emulators:start \
          --only auth,functions,firestore \
          --project nagaja-a6a8b"]