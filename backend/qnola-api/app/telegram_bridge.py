import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from app.push import send_apns_notification


router = APIRouter(prefix="/v1/telegram", tags=["telegram"])


def telegram_credentials() -> tuple[str | None, str | None]:
    api_id = os.environ.get("QNOLA_TELEGRAM_API_ID") or os.environ.get("QNOLA_API_ID")
    api_hash = os.environ.get("QNOLA_TELEGRAM_API_HASH") or os.environ.get("QNOLA_API_HASH")
    return api_id, api_hash


def telegram_session_path() -> Path:
    return Path(os.environ.get("QNOLA_TELEGRAM_SESSION_PATH", "./data/telegram"))


MEDIA_ROOT = Path(os.environ.get("QNOLA_MEDIA_ROOT", "./data/media")) / "telegram"
AVATAR_ROOT = MEDIA_ROOT / "avatars"
MESSAGE_MEDIA_ROOT = MEDIA_ROOT / "messages"
AVATAR_ROOT.mkdir(parents=True, exist_ok=True)
MESSAGE_MEDIA_ROOT.mkdir(parents=True, exist_ok=True)

_client: Any | None = None
_client_api_id: str | None = None
_client_api_hash: str | None = None
_updates_registered = False
_telegram_push_tokens: set[str] = set()


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


class TelegramPushTokenRequest(BaseModel):
    token: str = Field(min_length=16, max_length=255)
    platform: str = "ios"


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
    kind: str = "text"
    mediaUrl: str | None = None
    fileName: str | None = None
    mimeType: str | None = None
    thumbnailUrl: str | None = None
    source: str = "telegram"


def bridge_enabled() -> bool:
    api_id, api_hash = telegram_credentials()
    return bool(api_id and api_hash)


async def telegram_client():
    api_id, api_hash = telegram_credentials()
    if not api_id or not api_hash:
        raise HTTPException(status_code=503, detail="Telegram bridge is not configured")
    try:
        from telethon import TelegramClient
    except ImportError:
        raise HTTPException(status_code=503, detail="Telethon is not installed")

    global _client, _client_api_id, _client_api_hash

    # Recreate client if credentials changed or client doesn't exist
    if _client is None or _client_api_id != api_id or _client_api_hash != api_hash:
        import sys
        print(f"[telegram_client] Creating new client", file=sys.stderr)
        print(f"  api_id={api_id} (type: {type(api_id).__name__}, len: {len(str(api_id))})", file=sys.stderr)
        print(f"  api_hash={api_hash[:20] if api_hash else None}... (type: {type(api_hash).__name__}, len: {len(api_hash) if api_hash else 0})", file=sys.stderr)

        session_path = telegram_session_path()
        session_path_abs = session_path.resolve()  # Convert to absolute path
        session_path_str = str(session_path_abs)
        print(f"  session_path (abs)={session_path_str}", file=sys.stderr)
        session_path_abs.parent.mkdir(parents=True, exist_ok=True)

        try:
            api_id_int = int(api_id)
            print(f"  api_id_int={api_id_int}", file=sys.stderr)
            _client = TelegramClient(session_path_str, api_id_int, api_hash)
            print(f"  Client created successfully!", file=sys.stderr)
            _client_api_id = api_id
            _client_api_hash = api_hash
        except Exception as e:
            print(f"  ERROR creating client: {type(e).__name__}: {e}", file=sys.stderr)
            raise

    if not _client.is_connected():
        import sys
        print(f"[telegram_client] Connecting...", file=sys.stderr)
        try:
            await _client.connect()
            print(f"[telegram_client] Connected!", file=sys.stderr)
        except Exception as e:
            print(f"[telegram_client] ERROR connecting: {type(e).__name__}: {e}", file=sys.stderr)
            raise

    await ensure_update_handler(_client)
    return _client


async def ensure_update_handler(client: Any) -> None:
    global _updates_registered
    if _updates_registered:
        return
    try:
        from telethon import events
    except ImportError:
        return

    @client.on(events.NewMessage(incoming=True))
    async def handle_new_message(event: Any) -> None:
        if not _telegram_push_tokens:
            return
        message = event.message
        title = "Telegram"
        try:
            sender = await event.get_sender()
            title = display_name(sender)
        except Exception:
            pass
        body = getattr(message, "message", None) or "РќРѕРІРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ"
        for token in list(_telegram_push_tokens):
            try:
                await send_apns_notification(token, title, body)
            except Exception:
                pass

    _updates_registered = True


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


def media_kind(message: Any) -> str:
    if not getattr(message, "media", None):
        return "text"
    if getattr(message, "sticker", None):
        return "sticker"
    if getattr(message, "photo", None):
        return "photo"
    if getattr(message, "video", None):
        return "video"
    if getattr(message, "voice", None):
        return "voice"
    if getattr(message, "audio", None):
        return "audio"
    if getattr(message, "document", None):
        return "file"
    return "unsupported"


def media_metadata(message: Any) -> tuple[str | None, str | None]:
    file = getattr(message, "file", None)
    name = getattr(file, "name", None) or getattr(file, "title", None)
    mime_type = getattr(file, "mime_type", None)
    return name, mime_type


async def message_media_url(client: Any, message: Any, kind: str) -> str | None:
    if kind == "text":
        return None
    suffix = ""
    file = getattr(message, "file", None)
    ext = getattr(file, "ext", None)
    if ext:
        suffix = ext if str(ext).startswith(".") else f".{ext}"
    elif kind == "photo":
        suffix = ".jpg"
    target = MESSAGE_MEDIA_ROOT / f"{message.chat_id}_{message.id}{suffix}"
    if not target.exists():
        try:
            downloaded = await client.download_media(message, file=str(target))
            if not downloaded:
                return None
        except Exception:
            return None
    return f"/v1/telegram/media/{target.name}"


async def message_payload(client: Any, message: Any) -> TelegramMessage:
    sender = getattr(message, "sender", None)
    raw_date = getattr(message, "date", None) or datetime.now(timezone.utc)
    date = raw_date if raw_date.tzinfo else raw_date.replace(tzinfo=timezone.utc)
    kind = media_kind(message)
    file_name, mime_type = media_metadata(message)
    media_url = await message_media_url(client, message, kind)
    return TelegramMessage(
        id=int(message.id),
        senderName=display_name(sender) if sender and not bool(getattr(message, "out", False)) else None,
        text=getattr(message, "message", None) or "",
        date=date,
        outgoing=bool(getattr(message, "out", False)),
        kind=kind,
        mediaUrl=media_url,
        fileName=file_name,
        mimeType=mime_type,
        thumbnailUrl=media_url if kind in {"photo", "sticker"} else None,
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
    try:
        await client.send_code_request(request.phone)
        return {"sent": True}
    except Exception as error:
        error_name = error.__class__.__name__
        if "PhoneNumberInvalidError" in error_name or "InvalidPhoneError" in error_name:
            raise HTTPException(status_code=400, detail="РќРµРІРµСЂРЅС‹Р№ РЅРѕРјРµСЂ С‚РµР»РµС„РѕРЅР°.")
        if "ApiIdInvalidError" in error_name:
            raise HTTPException(status_code=503, detail="РќРµРІРµСЂРЅС‹Рµ Telegram API credentials.")
        if "SendCodeUnavailableError" in error_name:
            raise HTTPException(
                status_code=429,
                detail="Telegram РІСЂРµРјРµРЅРЅРѕ РЅРµ РјРѕР¶РµС‚ РѕС‚РїСЂР°РІРёС‚СЊ РЅРѕРІС‹Р№ РєРѕРґ РґР»СЏ СЌС‚РѕРіРѕ РЅРѕРјРµСЂР°. РќРµ РЅР°Р¶РёРјР°Р№ РїРѕРІС‚РѕСЂРЅСѓСЋ РѕС‚РїСЂР°РІРєСѓ: РїРѕРґРѕР¶РґРё, РїСЂРѕРІРµСЂСЊ РѕС„РёС†РёР°Р»СЊРЅС‹Р№ Telegram РёР»Рё РІРІРµРґРё РїРµСЂРІС‹Р№ СѓР¶Рµ РїСЂРёС€РµРґС€РёР№ РєРѕРґ.",
            )
        raise HTTPException(status_code=400, detail=str(error))


@router.post("/verify-code", response_model=TelegramState)
async def telegram_verify_code(request: TelegramVerifyCodeRequest):
    client = await telegram_client()
    try:
        await client.sign_in(phone=request.phone, code=request.code)
    except Exception as error:
        err_name = error.__class__.__name__
        if err_name == "PasswordHashInvalidError":
            raise HTTPException(status_code=401, detail="РќРµРІРµСЂРЅС‹Р№ РїР°СЂРѕР»СЊ Telegram 2FA.")
        if err_name == "SessionPasswordNeededError":
            if not request.password:
                raise HTTPException(status_code=401, detail="Р’РєР»СЋС‡РµРЅР° РґРІСѓС…СЌС‚Р°РїРЅР°СЏ РїСЂРѕРІРµСЂРєР° Telegram. Р’РІРµРґРё РїР°СЂРѕР»СЊ 2FA.")
            try:
                await client.sign_in(password=request.password)
            except Exception as pw_err:
                if pw_err.__class__.__name__ == "PasswordHashInvalidError":
                    raise HTTPException(status_code=401, detail="РќРµРІРµСЂРЅС‹Р№ РїР°СЂРѕР»СЊ Telegram 2FA.")
                raise HTTPException(status_code=401, detail=str(pw_err))
        else:
            raise HTTPException(status_code=401, detail=str(error))
    me = await client.get_me()
    return TelegramState(enabled=True, authorized=True, phone=getattr(me, "phone", None), userDisplayName=display_name(me))


@router.post("/push-token")
async def telegram_push_token(request: TelegramPushTokenRequest):
    _telegram_push_tokens.add(request.token)
    return {"registered": True}


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
        messages.append(await message_payload(client, message))
    return list(reversed(messages))


@router.post("/dialogs/{dialog_id}/send", response_model=TelegramMessage)
async def telegram_send_message(dialog_id: int, request: TelegramSendMessageRequest):
    client = await telegram_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Telegram session is not authorized")
    sent = await client.send_message(dialog_id, request.text)
    return await message_payload(client, sent)


@router.post("/dialogs/{dialog_id}/send-file", response_model=TelegramMessage)
async def telegram_send_file(dialog_id: int, file: UploadFile = File(...), caption: str | None = Form(None)):
    client = await telegram_client()
    if not await client.is_user_authorized():
        raise HTTPException(status_code=401, detail="Telegram session is not authorized")
    upload_dir = MEDIA_ROOT / "uploads"
    upload_dir.mkdir(parents=True, exist_ok=True)
    target = upload_dir / (file.filename or "upload.bin")
    with target.open("wb") as handle:
        while chunk := await file.read(1024 * 1024):
            handle.write(chunk)
    sent = await client.send_file(dialog_id, str(target), caption=caption or "")
    return await message_payload(client, sent)


@router.get("/avatars/{peer_id}.jpg")
def telegram_avatar(peer_id: int):
    target = AVATAR_ROOT / f"{peer_id}.jpg"
    if not target.exists():
        raise HTTPException(status_code=404, detail="Avatar not found")
    return FileResponse(target, media_type="image/jpeg")


@router.get("/media/{file_name}")
def telegram_media(file_name: str):
    target = MESSAGE_MEDIA_ROOT / file_name
    if not target.exists():
        raise HTTPException(status_code=404, detail="Media not found")
    return FileResponse(target)
