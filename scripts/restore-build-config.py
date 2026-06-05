#!/usr/bin/env python3
import base64
import json
import os
import sys
from pathlib import Path


def decode_text(raw: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "utf-16", "utf-16-le", "utf-16-be", "cp1251"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            pass
    raise SystemExit("Build config secret is not valid text. Save JSON as UTF-8 and encode the file bytes.")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: restore-build-config.py <output-json>", file=sys.stderr)
        return 2

    encoded = os.environ.get("TELEGRAM_IOS_BUILD_CONFIG_BASE64", "")
    if not encoded:
        print("Missing TELEGRAM_IOS_BUILD_CONFIG_BASE64.", file=sys.stderr)
        return 1

    try:
        raw = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        print(f"TELEGRAM_IOS_BUILD_CONFIG_BASE64 is not valid base64: {exc}", file=sys.stderr)
        return 1

    try:
        data = json.loads(decode_text(raw))
    except Exception as exc:
        print(f"TELEGRAM_IOS_BUILD_CONFIG_BASE64 does not decode to valid JSON: {exc}", file=sys.stderr)
        return 1

    required = {
        "bundle_id": "com.skat111.qnola",
        "api_id": "",
        "api_hash": "",
        "team_id": "QNOLA0000",
        "app_center_id": "0",
        "is_internal_build": "true",
        "is_appstore_build": "false",
        "appstore_id": "0",
        "app_specific_url_scheme": "qnola",
        "premium_iap_product_id": "",
        "enable_siri": False,
        "enable_icloud": False,
    }

    for key, value in required.items():
        if key not in data or data[key] in (None, ""):
            data[key] = value

    missing_real_values = [
        key for key in ("api_id", "api_hash")
        if not str(data.get(key, "")).strip() or str(data.get(key, "")).startswith("YOUR_")
    ]
    if missing_real_values:
        print(f"Build config must contain real values for: {', '.join(missing_real_values)}", file=sys.stderr)
        return 1

    data["bundle_id"] = str(data["bundle_id"]).replace("Telegram", "Qnola").replace("telegram", "qnola")
    if data.get("app_specific_url_scheme") in ("", "tg", "telegram"):
        data["app_specific_url_scheme"] = "qnola"

    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote normalized build config to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
