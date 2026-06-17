"""
NaGaJa-Pi 알람 실행기
user_id.txt(BLE로 수신된 userId)를 읽어 Firestore의 dailyPlans를 실시간 구독합니다.
finalAlarmTime에 도달하면 GPIO(LED / 부저)로 물리 알람을 동작시킵니다.

실행:
    python3 alarm_runner.py

요구사항:
    - serviceAccountKey.json (Firebase Console → 서비스 계정 → 새 비공개 키 생성)
    - user_id.txt (ble_receiver.py 실행 후 앱에서 연결 시 자동 생성)
    - pip3 install firebase-admin RPi.GPIO
"""

import logging
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

# GPIO 핀 번호 (BCM 기준, 실제 배선에 맞게 수정)
LED_PIN    = 18
BUZZER_PIN = 23

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

USER_ID_FILE       = Path(__file__).parent / "user_id.txt"
SERVICE_ACCOUNT    = Path(__file__).parent / "serviceAccountKey.json"


# ── Firestore 초기화 ───────────────────────────────────────────────────────────

cred = credentials.Certificate(str(SERVICE_ACCOUNT))
firebase_admin.initialize_app(cred)
db = firestore.client()


# ── GPIO 초기화 ────────────────────────────────────────────────────────────────

try:
    import RPi.GPIO as GPIO
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(LED_PIN, GPIO.OUT, initial=GPIO.LOW)
    GPIO.setup(BUZZER_PIN, GPIO.OUT, initial=GPIO.LOW)
    HAS_GPIO = True
    logger.info("GPIO 초기화 완료")
except ImportError:
    HAS_GPIO = False
    logger.warning("RPi.GPIO 없음 — GPIO 제어 없이 실행 (개발 환경)")


# ── 알람 제어 ──────────────────────────────────────────────────────────────────

_alarm_timer: threading.Timer | None = None


def trigger_alarm():
    logger.info("알람 발동!")
    if HAS_GPIO:
        GPIO.output(LED_PIN, GPIO.HIGH)
        GPIO.output(BUZZER_PIN, GPIO.HIGH)
        time.sleep(30)  # 30초 울림
        GPIO.output(LED_PIN, GPIO.LOW)
        GPIO.output(BUZZER_PIN, GPIO.LOW)


def schedule_alarm(alarm_dt: datetime):
    global _alarm_timer
    if _alarm_timer:
        _alarm_timer.cancel()

    now = datetime.now(timezone.utc)
    delay = (alarm_dt - now).total_seconds()

    if delay <= 0:
        logger.info(f"알람 시각 이미 지남: {alarm_dt}")
        return

    logger.info(f"알람 예약: {alarm_dt} (약 {int(delay)}초 후)")
    _alarm_timer = threading.Timer(delay, trigger_alarm)
    _alarm_timer.daemon = True
    _alarm_timer.start()


# ── Firestore 구독 ─────────────────────────────────────────────────────────────

def on_plans_snapshot(col_snapshot, changes, read_time):
    today = datetime.now().strftime("%Y-%m-%d")
    for doc in col_snapshot:
        data = doc.to_dict()
        plan_date = doc.id.split("_")[0]  # "{planDate}_{scheduleId}" 형식
        if plan_date != today:
            continue
        alarm_ts = data.get("finalAlarmTime")
        if alarm_ts is None:
            continue
        alarm_dt = alarm_ts.astimezone(timezone.utc) if hasattr(alarm_ts, "astimezone") else alarm_ts
        logger.info(f"[Firestore] 오늘 알람 시각: {alarm_dt} (planId={doc.id})")
        schedule_alarm(alarm_dt)
        break  # 첫 번째 오늘 플랜만 사용


def start_watching(user_id: str):
    logger.info(f"Firestore 구독 시작: userId={user_id}")
    col_ref = (
        db.collection("users")
          .document(user_id)
          .collection("dailyPlans")
    )
    return col_ref.on_snapshot(on_plans_snapshot)


# ── 메인 ──────────────────────────────────────────────────────────────────────

def main():
    if not USER_ID_FILE.exists():
        logger.error(
            f"{USER_ID_FILE} 파일이 없습니다. "
            "먼저 ble_receiver.py를 실행하고 앱에서 '연결' 버튼을 누르세요."
        )
        return

    user_id = USER_ID_FILE.read_text().strip()
    if not user_id:
        logger.error("user_id.txt가 비어 있습니다.")
        return

    watch = start_watching(user_id)

    try:
        logger.info("알람 대기 중... (Ctrl+C로 종료)")
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        logger.info("종료")
    finally:
        watch.unsubscribe()
        if HAS_GPIO:
            GPIO.cleanup()


if __name__ == "__main__":
    main()
