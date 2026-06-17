"""
NaGaJa-Pi BLE GATT 서버
Flutter 앱에서 BLE로 연결해 userId를 수신하고 파일에 저장합니다.

실행:
    sudo python3 ble_receiver.py

요구사항:
    - BlueZ 블루투스 스택 (sudo apt-get install bluetooth bluez)
    - bless 라이브러리 (pip3 install bless)
"""

import asyncio
import logging
from pathlib import Path

from bless import (
    BlessServer,
    BlessGATTCharacteristic,
    GATTCharacteristicProperties,
    GATTAttributePermissions,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
CHAR_UUID    = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
USER_ID_FILE = Path(__file__).parent / "user_id.txt"


def read_request(characteristic: BlessGATTCharacteristic, **kwargs) -> bytearray:
    try:
        return bytearray(USER_ID_FILE.read_text().encode())
    except FileNotFoundError:
        return bytearray()


def write_request(characteristic: BlessGATTCharacteristic, value: bytearray, **kwargs):
    user_id = value.decode("utf-8").strip()
    if not user_id:
        return
    USER_ID_FILE.write_text(user_id)
    logger.info(f"[BLE] userId 수신 및 저장 완료: {user_id}")


async def main():
    server = BlessServer(name="NaGaJa-Pi")
    server.read_request_func  = read_request
    server.write_request_func = write_request

    await server.add_new_service(SERVICE_UUID)

    char_flags = (
        GATTCharacteristicProperties.read
        | GATTCharacteristicProperties.write
        | GATTCharacteristicProperties.write_without_response
    )
    permissions = (
        GATTAttributePermissions.readable
        | GATTAttributePermissions.writeable
    )
    await server.add_new_characteristic(
        SERVICE_UUID, CHAR_UUID, char_flags, None, permissions
    )

    await server.start()
    logger.info("NaGaJa-Pi BLE GATT 서버 시작. 앱에서 '기기 연결' 버튼을 누르세요.")

    try:
        await asyncio.sleep(float("inf"))
    except (asyncio.CancelledError, KeyboardInterrupt):
        pass
    finally:
        await server.stop()
        logger.info("BLE 서버 종료")


if __name__ == "__main__":
    asyncio.run(main())
