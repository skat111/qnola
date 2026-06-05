# Qnola Telethon Backend

This backend uses Telethon to access Telegram through the user API. The iOS app
talks to it over HTTP.

## Run

```bash
cd backend/telethon
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
set QNOLA_API_ID=24725230
set QNOLA_API_HASH=put_your_api_hash_here
uvicorn main:app --host 0.0.0.0 --port 8000
```

Use your server URL in the Qnola iOS settings.
