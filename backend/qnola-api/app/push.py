import os
import time
from functools import lru_cache

import httpx
from jose import jwt


APNS_KEY_ID = os.environ.get("QNOLA_APNS_KEY_ID")
APNS_TEAM_ID = os.environ.get("QNOLA_APNS_TEAM_ID")
APNS_BUNDLE_ID = os.environ.get("QNOLA_APNS_BUNDLE_ID", "com.skat111.qnola")
APNS_PRIVATE_KEY = os.environ.get("QNOLA_APNS_PRIVATE_KEY")
APNS_USE_SANDBOX = os.environ.get("QNOLA_APNS_SANDBOX", "1") == "1"


def apns_configured() -> bool:
    return bool(APNS_KEY_ID and APNS_TEAM_ID and APNS_BUNDLE_ID and APNS_PRIVATE_KEY)


@lru_cache(maxsize=1)
def apns_token() -> str:
    return jwt.encode(
        {"iss": APNS_TEAM_ID, "iat": int(time.time())},
        APNS_PRIVATE_KEY.replace("\\n", "\n"),
        algorithm="ES256",
        headers={"kid": APNS_KEY_ID},
    )


async def send_apns_notification(device_token: str, title: str, body: str, badge: int | None = None) -> None:
    if not apns_configured():
        return
    host = "api.sandbox.push.apple.com" if APNS_USE_SANDBOX else "api.push.apple.com"
    payload = {"aps": {"alert": {"title": title, "body": body}, "sound": "default"}}
    if badge is not None:
        payload["aps"]["badge"] = badge
    headers = {
        "authorization": f"bearer {apns_token()}",
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
    }
    async with httpx.AsyncClient(http2=True, timeout=10) as client:
        response = await client.post(f"https://{host}/3/device/{device_token}", headers=headers, json=payload)
        response.raise_for_status()
