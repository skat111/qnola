import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError


api_id = int(os.environ.get("QNOLA_API_ID", "0"))
api_hash = os.environ.get("QNOLA_API_HASH", "")
session_path = Path(os.environ.get("QNOLA_SESSION_PATH", "./data/qnola.session"))
session_path.parent.mkdir(parents=True, exist_ok=True)

client = TelegramClient(str(session_path), api_id, api_hash)
app = FastAPI(title="Qnola Telethon Backend")


class LoginCodeRequest(BaseModel):
    phone: str


class CompleteLoginRequest(BaseModel):
    phone: str
    code: str
    password: Optional[str] = None


class SendMessageRequest(BaseModel):
    chatId: int
    text: str


async def ensure_client():
    if api_id == 0 or not api_hash:
        raise HTTPException(status_code=500, detail="QNOLA_API_ID and QNOLA_API_HASH are required")
    if not client.is_connected():
        await client.connect()


@app.on_event("startup")
async def startup():
    await ensure_client()


@app.on_event("shutdown")
async def shutdown():
    await client.disconnect()


@app.get("/auth/state")
async def auth_state():
    await ensure_client()
    authorized = await client.is_user_authorized()
    user = await client.get_me() if authorized else None
    return {
        "authorized": authorized,
        "phone": getattr(user, "phone", None) if user else None,
        "userDisplayName": f"{getattr(user, 'first_name', '') or ''} {getattr(user, 'last_name', '') or ''}".strip() if user else None,
    }


@app.post("/auth/send-code")
async def send_code(request: LoginCodeRequest):
    await ensure_client()
    await client.send_code_request(request.phone)
    return {}


@app.post("/auth/complete")
async def complete_login(request: CompleteLoginRequest):
    await ensure_client()
    try:
        await client.sign_in(request.phone, request.code)
    except SessionPasswordNeededError:
        if not request.password:
            raise HTTPException(status_code=401, detail="Two-step verification password required")
        await client.sign_in(password=request.password)
    return await auth_state()


@app.get("/dialogs")
async def dialogs():
    await ensure_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Not authorized")

    result = []
    async for dialog in client.iter_dialogs(limit=100):
        message = dialog.message
        result.append({
            "id": dialog.id,
            "title": dialog.name or "Untitled",
            "lastMessage": getattr(message, "message", None) if message else None,
            "unreadCount": dialog.unread_count or 0,
            "isMuted": bool(getattr(dialog, "is_muted", False)),
        })
    return result


@app.get("/dialogs/{chat_id}/messages")
async def messages(chat_id: int):
    await ensure_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Not authorized")

    result = []
    async for message in client.iter_messages(chat_id, limit=80):
        sender = await message.get_sender()
        name = " ".join(part for part in [
            getattr(sender, "first_name", None),
            getattr(sender, "last_name", None),
        ] if part)
        date = message.date or datetime.now(timezone.utc)
        result.append({
            "id": message.id,
            "senderName": name or getattr(sender, "username", None),
            "text": message.message or "",
            "date": date.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "outgoing": bool(message.out),
        })
    return list(reversed(result))


@app.post("/messages/send")
async def send_message(request: SendMessageRequest):
    await ensure_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Not authorized")
    message = await client.send_message(request.chatId, request.text)
    date = message.date or datetime.now(timezone.utc)
    return {
        "id": message.id,
        "senderName": None,
        "text": message.message or "",
        "date": date.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "outgoing": True,
    }

