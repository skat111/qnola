# qnola

Qnola is a build wrapper for a private iOS Telegram fork.

The repository now contains three tracks:

- `apps/ios`: Qnola, a SwiftUI iOS client with dark Liquid Glass chat UI, demo mode, and first-party qnola API client scaffolding.
- `backend/qnola-api`: first-party FastAPI backend with `/v1` REST, WebSocket realtime, auth, chats, messages, and uploads.
- `backend/telethon`: deprecated Telegram bridge prototype kept for reference.
- Telegram-iOS wrapper scripts: an experimental upstream Telegram iOS build path that still needs Apple provisioning for device IPA.

## Sources

- Telegram iOS: https://github.com/TelegramMessenger/Telegram-iOS
- AyuGram Android: https://github.com/AyuGram/AyuGram4A
- AyuGram Desktop: https://github.com/AyuGram/AyuGramDesktop
- Telethon: https://docs.telethon.dev/

## Qnola

Use this for an installable IPA without Telegram-iOS Bazel signing issues.

- iOS app: `apps/ios`
- Backend: `backend/qnola-api`
- App icon source: `assets/q.svg` from https://www.svgrepo.com/show/535581/q.svg
- GitHub Actions workflow: `Build Qnola IPA`
- Artifact: `qnola-ipa`

## Safe Mod Scope

Qnola can add iPhone-friendly customizations that do not bypass other users'
privacy expectations:

- separate app name, bundle id, and icon;
- local settings screen for Qnola options;
- interface customization, fonts, layout density, and themes;
- streamer mode that hides local names, avatars, and message previews on screen;
- local dialog/message filters for display only;
- export/import of local Qnola settings.

Current build automation applies:

- visible brand replacement in plist/localization/config text files;
- black and white generated app icons;
- `CFBundleDisplayName = Qnola` where plist files allow it;
- a generated `Qnola/QnolaFeatures.json` feature manifest inside the build tree;
- a generated official SwiftUI Liquid Glass customization pack under `Qnola/LiquidGlass`;
- optional Telegram iOS patches from `patches/*.patch`.

Do not add patches for:

- saving deleted or self-destructing messages;
- bypassing read receipts, online status, typing status, or secret chat limits;
- screenshots in secret chats;
- using official Telegram application keys;
- pretending to be the official Telegram app.

## Required GitHub Secrets

Set these in `skat111/qnola` repository settings before running the workflow:

- `TELEGRAM_IOS_BUILD_CONFIG_BASE64`
  - Base64 of the Telegram iOS build configuration JSON.
  - Usually based on `build-system/template_minimal_development_configuration.json`.
- `TELEGRAM_IOS_CODESIGNING_TAR_BASE64` only for `build_mode=signed`
  - Base64 of a `.tar.gz` archive containing signing data expected by Telegram's
    `--codesigningInformationPath`.

Use `build_mode=unsigned` to compile a simulator sanity artifact without Apple
signing data. A real installable arm64 IPA still requires provisioning data, even
if Sideloadly will re-sign it later, because Telegram iOS is built through
`rules_apple` and device analysis requires a provisioning profile.

Use `config/qnola-build.example.json` as the starting point for the build config.
Encode it after filling real values:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\qnola-build.json")) | Set-Clipboard
```

For `build_mode=unsigned`, `team_id` can stay as `QNOLA0000`. Fill only
`api_id` and `api_hash` with real values from https://my.telegram.org/apps.

## Build

1. Push this repository to GitHub.
2. Add the required secrets.
3. Open Actions -> `Build Qnola IPA`.
4. Run the workflow manually.
5. Download the `qnola-ipa` artifact from the latest successful run.

## Patches

Put `git format-patch` compatible files into `patches/`.

The workflow applies them in lexical order:

```bash
git am ../patches/*.patch
```

Keep patches small and buildable. If a patch adds a Swift/Objective-C file, confirm
that it is included by Telegram iOS Bazel targets.

See `docs/features.md` before adding AyuGram-inspired patches.
