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

## Tests

```bash
python -m pytest tests
```
