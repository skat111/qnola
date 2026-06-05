# Qnola Feature Scope

Qnola is the iOS Telegram fork name and app brand.

## Brand

- App display name: `Qnola`
- Bundle/product naming should use `Qnola` / `qnola` where the build configuration allows it.
- App icon style: black and white.
- User-visible Telegram branding should be replaced with Qnola where it is part of the app identity.

## AyuGram-Inspired Features That Are Allowed

These are safe to implement in iOS patches:

- Streamer mode: hide local names, avatars, phone numbers, usernames, and message previews on screen.
- Local message and dialog filters that only affect local display.
- Local appearance controls: font size, chat density, bubble shape, theme presets.
- Local edited/deleted labels for content already present in the local app state.
- Local privacy dashboard explaining which Qnola settings are enabled.
- Local backup/export of Qnola settings.

## Features Not To Implement

Do not add features that bypass other users' privacy expectations or Telegram protocol controls:

- viewing deleted messages after the sender deleted them;
- saving self-destructing or TTL media after expiry;
- bypassing read receipts, online status, typing status, or secret chat restrictions;
- screenshots in secret chats;
- use of official Telegram app keys;
- pretending to be the official Telegram app in session lists or UI.

If a future patch touches message state, network requests, account presence, secret chats, or TTL media, review it against this file before adding it to `patches/`.

