import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field


router = APIRouter(prefix="/v1/telegram", tags=["telegram"])

API_ID = os.environ.get("QNOLA_TELEGRAM_API_ID") or os.environ.get("QNOLA_API_ID")
API_HASH = os.environ.get("QNOLA_TELEGRAM_API_HASH") or os.environ.get("QNOLA_API_HASH")
SESSION_PATH = os.environ.get("QNOLA_TELEGRAM_SESSION_PATH", "./data/telegram")
MEDIA_ROOT = Path(os.environ.get("QNOLA_MEDIA_ROOT", "./data/media")) / "telegram"
AVATAR_ROOT = MEDIA_ROOT / "avatars"
AVATAR_ROOT.mkdir(parents=True, exist_ok=True)

_client: Any | None = None


class TelegramState(BaseModel):
    enabled: bool
    authorized: bool
    phone: str | None = None
    userDisplayName: str | None = None


class TelegramSendCodeRequest(BaseModel):
    phone: str = Field(min_length=5, max_length=32)


class TelegramVerifyCodeRequest(BaseModel):
    phone: str
    code: str
    password: str | None = None


class TelegramSendMessageRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4096)


class TelegramDialog(BaseModel):
    id: int
    title: str
    lastMessage: str | None = None
    unreadCount: int = 0
    isMuted: bool = False
    avatarUrl: str | None = None
    source: str = "telegram"


class TelegramMessage(BaseModel):
    id: int
    senderName: str | None = None
    text: str
    date: datetime
    outgoing: bool
    source: str = "telegram"


def bridge_enabled() -> bool:
    return bool(API_ID and API_HASH)


async def telegram_client():
    if not bridge_enabled():
        raise HTTPException(status_code=503, detail="Telegram bridge is not configured")
    try:
        from telethon import TelegramClient
    except ImportError:
        raise HTTPException(status_code=503, detail="Telethon is not installed")

    global _client
    if _client is None:
        Path(SESSION_PATH).parent.mkdir(parents=True, exist_ok=True)
        _client = TelegramClient(SESSION_PATH, int(API_ID), API_HASH)
    if not _client.is_connected():
        await _client.connect()
    return _client


def display_name(user: Any) -> str:
    parts = [getattr(user, "first_name", None), getattr(user, "last_name", None)]
    name = " ".join(part for part in parts if part).strip()
    return name or getattr(user, "username", None) or "Telegram User"


async def dialog_avatar_url(client: Any, dialog: Any) -> str | None:
    peer_id = int(dialog.id)
    target = AVATAR_ROOT / f"{peer_id}.jpg"
    if not target.exists():
        try:
            downloaded = await client.download_profile_photo(dialog.entity, file=str(target))
            if not downloaded:
                return None
        except Exception:
            return None
    return f"/v1/telegram/avatars/{peer_id}.jpg"


def message_payload(message: Any) -> TelegramMessage:
    sender = getattr(message, "sender", None)
    raw_date = getattr(message, "date", None) or datetime.now(timezone.utc)
    date = raw_date if raw_date.tzinfo else raw_date.replace(tzinfo=timezone.utc)
    return TelegramMessage(
        id=int(message.id),
        senderName=display_name(sender) if sender and not bool(getattr(message, "out", False)) else None,
        text=getattr(message, "message", None) or "",
        date=date,
        outgoing=bool(getattr(message, "out", False)),
    )


@router.get("/state", response_model=TelegramState)
async def telegram_state():
    if not bridge_enabled():
        return TelegramState(enabled=False, authorized=False)
    client = await telegram_client()
    authorized = await client.is_user_authorized()
    if not authorized:
        return TelegramState(enabled=True, authorized=False)
    me = await client.get_me()
    return TelegramState(enabled=True, authorized=True, phone=getattr(me, "phone", None), userDisplayName=display_name(me))


@router.post("/send-code")
async def telegram_send_code(request: TelegramSendCodeRequest):
    client = await telegram_client()
    await client.send_code_request(request.phone)
    return {"sent": True}


@router.post("/verify-code", response_model=TelegramState)
async def telegram_verify_code(request: TelegramVerifyCodeRequest):
    client = await telegram_client()
    try:
        await client.sign_in(phone=request.phone, code=request.code)
    except Exception as error:
        if error.__class__.__name__ != "SessionPasswordNeededError" or not request.password:
            raise HTTPException(status_code=401, detail=str(error))
        await client.sign_in(password=request.password)
    me = await client.get_me()
    return TelegramState(enabled=True, authorized=True, phone=getattr(me, "phone", None), userDisplayName=display_name(me))


@router.get("/dialogs", response_model=list[TelegramDialog])
async def telegram_dialogs(limit: int = Query(50, ge=1, le=100)):
    client = await telegram_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Telegram session is not authorized")
    items: list[TelegramDialog] = []
    async for dialog in client.iter_dialogs(limit=limit):
        items.append(
            TelegramDialog(
                id=int(dialog.id),
                title=dialog.name or "Telegram Chat",
                lastMessage=(getattr(dialog.message, "message", None) if dialog.message else None),
                unreadCount=int(getattr(dialog, "unread_count", 0) or 0),
                isMuted=bool(getattr(dialog, "notify_settings", None) and getattr(dialog.notify_settings, "mute_until", None)),
                avatarUrl=await dialog_avatar_url(client, dialog),
            )
        )
    return items


@router.get("/dialogs/{dialog_id}/messages", response_model=list[TelegramMessage])
async def telegram_messages(dialog_id: int, limit: int = Query(50, ge=1, le=100)):
    client = await telegram_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Telegram session is not authorized")
    messages = []
    async for message in client.iter_messages(dialog_id, limit=limit):
        messages.append(message_payload(message))
    return list(reversed(messages))


@router.post("/dialogs/{dialog_id}/send", response_model=TelegramMessage)
async def telegram_send_message(dialog_id: int, request: TelegramSendMessageRequest):
    client = await telegram_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Telegram session is not authorized")
    sent = await client.send_message(dialog_id, request.text)
    return message_payload(sent)


@router.get("/avatars/{peer_id}.jpg")
def telegram_avatar(peer_id: int):
    target = AVATAR_ROOT / f"{peer_id}.jpg"
    if not target.exists():
        raise HTTPException(status_code=404, detail="Avatar not found")
    return FileResponse(target, media_type="image/jpeg")
