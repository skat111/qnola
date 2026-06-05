# qnola API

First-party FastAPI backend for qnola.

## Local Run

```bash
cd backend/qnola-api
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The default database is `sqlite:///./data/qnola.db` for local development.

## Docker Run

```bash
cd backend/qnola-api
docker compose up --build
```

This starts FastAPI, Postgres, and Redis. The API listens on `http://127.0.0.1:8000`.

## Development SMS

Until an SMS provider is wired, the dev login code is controlled by:

```bash
QNOLA_DEV_SMS_CODE=111111
```

## Telegram Sync Bridge

The first-party backend can also expose a personal Telegram sync bridge for
development builds. It uses Telethon with your own Telegram API credentials and
stores one local Telegram session on the server.

```bash
QNOLA_TELEGRAM_API_ID=123456
QNOLA_TELEGRAM_API_HASH=your_hash
QNOLA_TELEGRAM_SESSION_PATH=./data/telegram
uvicorn app.main:app --reload
```

Bridge endpoints live under `/v1/telegram/*`:

- `GET /v1/telegram/state`
- `POST /v1/telegram/send-code`
- `POST /v1/telegram/verify-code`
- `GET /v1/telegram/dialogs`
- `GET /v1/telegram/dialogs/{id}/messages`
- `POST /v1/telegram/dialogs/{id}/send`
- `GET /v1/telegram/avatars/{peerId}.jpg`

This is a compatibility bridge, not the final multi-user qnola account model.
Do not use official Telegram application keys.

## Push Notifications

The API accepts APNs device tokens at:

```http
POST /v1/devices/push-token
Authorization: Bearer <accessToken>
```

Actual delivery is enabled when these environment variables are set:

```bash
QNOLA_APNS_KEY_ID=ABC123DEFG
QNOLA_APNS_TEAM_ID=TEAMID1234
QNOLA_APNS_BUNDLE_ID=com.skat111.qnola
QNOLA_APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
QNOLA_APNS_SANDBOX=1
```

The iOS app requests permission and registers with APNs when it launches.

## Tests

```bash
python -m pytest tests
```
