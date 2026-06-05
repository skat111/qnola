# qnola Backend Contract

The current app targets a first-party qnola backend under `/v1`.

## Auth

- `POST /v1/auth/send-code`
- `POST /v1/auth/verify-code`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`

`verify-code` returns:

```json
{
  "accessToken": "jwt",
  "refreshToken": "opaque-token",
  "user": {
    "id": 1,
    "phone": "+10000000000",
    "displayName": "Alex",
    "username": "alex",
    "bio": ""
  }
}
```

Authenticated requests use:

```http
Authorization: Bearer <accessToken>
```

## Users

- `GET /v1/me`
- `PATCH /v1/me`
- `GET /v1/users/search?username=<query>`

## Chats

- `GET /v1/chats`
- `POST /v1/chats/private`
- `POST /v1/chats/group`
- `PATCH /v1/chats/{id}`

Chat response:

```json
{
  "id": 1,
  "type": "private",
  "title": "Mira",
  "participants": [],
  "lastMessage": null,
  "unreadCount": 0,
  "isMuted": false,
  "isPinned": false,
  "isArchived": false,
  "updatedAt": "2026-06-06T00:00:00Z"
}
```

## Messages

- `GET /v1/chats/{id}/messages?after=&before=&limit=`
- `POST /v1/chats/{id}/messages`
- `PATCH /v1/messages/{id}`
- `DELETE /v1/messages/{id}`

Message kinds: `text`, `photo`, `file`.

Message statuses: `pending`, `sent`, `delivered`, `read`, `failed`.

## Uploads

- `POST /v1/uploads`
- `GET /v1/files/{fileId}`

`POST /v1/uploads` accepts multipart field `file`.

## Push Devices

- `POST /v1/devices/push-token`

Payload:

```json
{ "token": "apns-device-token", "platform": "ios" }
```

The endpoint stores APNs tokens for push-ready delivery. Production push sending
still requires Apple APNs credentials on the backend.

## Realtime

`WS /v1/realtime?token=<accessToken>`

Server event examples:

```json
{ "type": "message.created", "chatId": 1, "message": {} }
{ "type": "typing", "chatId": 1, "userId": 2 }
{ "type": "read", "chatId": 1, "userId": 2 }
```

## Telegram Sync Bridge

For a development build that mirrors Telegram dialogs, the same backend exposes
an optional bridge under `/v1/telegram`. The bridge is enabled only when the
server has `QNOLA_TELEGRAM_API_ID` and `QNOLA_TELEGRAM_API_HASH`.

- `GET /v1/telegram/state`
- `POST /v1/telegram/send-code`
- `POST /v1/telegram/verify-code`
- `GET /v1/telegram/dialogs`
- `GET /v1/telegram/dialogs/{id}/messages`
- `POST /v1/telegram/dialogs/{id}/send`
- `GET /v1/telegram/avatars/{peerId}.jpg`

Dialog payloads include `avatarUrl` so the iOS chat list can show Telegram
profile photos when available.
