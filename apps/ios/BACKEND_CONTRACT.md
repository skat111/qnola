# qnola Backend Contract

The iOS app only needs a small messenger API. Implement these endpoints on any
backend stack and keep dates in ISO-8601 format.

## Auth

`GET /auth/state`

```json
{
  "authorized": true,
  "phone": "+10000000000",
  "userDisplayName": "Alex"
}
```

`POST /auth/send-code`

```json
{
  "phone": "+10000000000"
}
```

Returns `{}`.

`POST /auth/complete`

```json
{
  "phone": "+10000000000",
  "code": "12345",
  "password": null
}
```

Returns the same shape as `/auth/state`.

## Dialogs

`GET /dialogs`

```json
[
  {
    "id": 1,
    "title": "Design Chat",
    "lastMessage": "See you tomorrow",
    "unreadCount": 2,
    "isMuted": false
  }
]
```

## Messages

`GET /dialogs/{chatId}/messages`

```json
[
  {
    "id": 101,
    "senderName": "Alex",
    "text": "Hello",
    "date": "2026-06-05T18:00:00Z",
    "outgoing": false
  }
]
```

`POST /messages/send`

```json
{
  "chatId": 1,
  "text": "Hello"
}
```

Returns the created message:

```json
{
  "id": 102,
  "senderName": null,
  "text": "Hello",
  "date": "2026-06-05T18:01:00Z",
  "outgoing": true
}
```
