#!/usr/bin/env bash
set -euo pipefail

echo "Applying Qnola safe feature defaults."

mkdir -p Qnola
cat > Qnola/QnolaFeatures.json <<'JSON'
{
  "appName": "Qnola",
  "iconStyle": "black-white",
  "features": {
    "streamerMode": {
      "defaultEnabled": false,
      "localOnly": true,
      "hides": [
        "displayNames",
        "usernames",
        "phoneNumbers",
        "avatars",
        "messagePreviews"
      ]
    },
    "localFilters": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "appearanceTweaks": {
      "defaultEnabled": true,
      "localOnly": true
    },
    "qnolaSettings": {
      "defaultEnabled": true,
      "localOnly": true
    },
    "localNotes": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "compactChatList": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "monochromeInterface": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "hideStoriesSurface": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "hideReactionsSurface": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "hidePremiumUpsells": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "localKeywordMute": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "localArchiveRules": {
      "defaultEnabled": false,
      "localOnly": true
    },
    "settingsExport": {
      "defaultEnabled": true,
      "localOnly": true
    },
    "liquidGlassMessageTexture": {
      "defaultEnabled": true,
      "localOnly": true,
      "requires": "iOS 26 SDK for official SwiftUI glassEffect; fallback material on older systems",
      "presets": [
        "system",
        "liquidGlass",
        "liquidGlassTinted",
        "liquidGlassMono",
        "liquidGlassProminent"
      ]
    }
  },
  "disabledFeatures": [
    "deletedMessageViewing",
    "ttlMediaSaving",
    "readReceiptBypass",
    "onlineStatusBypass",
    "typingStatusBypass",
    "secretChatScreenshotBypass"
  ]
}
JSON

cat > Qnola/README.txt <<'TEXT'
Qnola local mod manifest.

This build enables Qnola branding and safe local-only feature defaults.
Protocol bypass features are intentionally not included.
TEXT

if [[ -d "Telegram" ]]; then
  find Telegram \
    -type f \
    \( -name 'Info.plist' -o -name 'InfoBazel.plist' \) \
    -print0 | while IFS= read -r -d '' plist; do
      if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Qnola" "$plist" 2>/dev/null || \
          /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Qnola" "$plist" 2>/dev/null || true
      fi
    done
fi

if [[ -f "build-system/ci-configuration.json" ]]; then
  python3 - "$PWD/build-system/ci-configuration.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["bundle_id"] = data.get("bundle_id", "com.skat111.qnola").replace("Telegram", "Qnola").replace("telegram", "qnola")
if data.get("app_specific_url_scheme") in ("tg", "telegram", ""):
    data["app_specific_url_scheme"] = "qnola"
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
fi

echo "Qnola safe feature defaults applied."
