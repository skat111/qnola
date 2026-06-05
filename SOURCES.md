# Checked Sources

Checked on 2026-06-03.

## Telegram iOS

- Repository: `TelegramMessenger/Telegram-iOS`
- URL: https://github.com/TelegramMessenger/Telegram-iOS
- Branch observed: `master`
- Build system: `build-system/Make/Make.py`
- IPA command shape:

```bash
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/telegram-bazel-cache" \
  build \
  --configurationPath=build-system/ci-configuration.json \
  --codesigningInformationPath=build-system/codesigning \
  --buildNumber="$GITHUB_RUN_NUMBER" \
  --configuration=release_arm64
```

Telegram's README requires third-party apps to use their own `api_id`, avoid the
Telegram name/logo unless clearly marked unofficial, protect user privacy, and
publish changed source as required by the license.

## AyuGram4A

- Repository: `AyuGram/AyuGram4A`
- URL: https://github.com/AyuGram/AyuGram4A
- Branch observed: `rewrite`
- Fork of `exteraSquad/exteraGram`
- README names `AyuMessageUtils` and `AyuHistoryHook` as key implementation points.
- README lists ghost mode, message history, message filters, local premium, and
  AyuSync.

## AyuGramDesktop

- Repository: `AyuGram/AyuGramDesktop`
- URL: https://github.com/AyuGram/AyuGramDesktop
- Branch observed: `dev`
- Fork of `telegramdesktop/tdesktop`
- README lists ghost mode, messages history, anti-recall, streamer mode, font
  customization, translator, and appearance changes.

