import os
import secrets
import shutil
from datetime import datetime, timedelta, timezone
from enum import Enum
from pathlib import Path
from typing import Annotated, Any

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, DateTime, Enum as SAEnum, ForeignKey, Integer, String, Text, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, relationship, sessionmaker

from app.telegram_bridge import router as telegram_router


DATABASE_URL = os.environ.get("QNOLA_DATABASE_URL", "sqlite:///./data/qnola.db")
JWT_SECRET = os.environ.get("QNOLA_JWT_SECRET", "dev-secret-change-me")
DEV_SMS_CODE = os.environ.get("QNOLA_DEV_SMS_CODE", "111111")
MEDIA_ROOT = Path(os.environ.get("QNOLA_MEDIA_ROOT", "./data/media"))
ACCESS_TOKEN_MINUTES = int(os.environ.get("QNOLA_ACCESS_TOKEN_MINUTES", "60"))
REFRESH_TOKEN_DAYS = int(os.environ.get("QNOLA_REFRESH_TOKEN_DAYS", "30"))

Path("./data").mkdir(exist_ok=True)
MEDIA_ROOT.mkdir(parents=True, exist_ok=True)

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {})
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)
password_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def now_utc() -> datetime:
    return datetime.utcnow()


class Base(DeclarativeBase):
    pass


class ChatType(str, Enum):
    private = "private"
    group = "group"


class MessageKind(str, Enum):
    text = "text"
    photo = "photo"
    file = "file"


class MessageStatus(str, Enum):
    pending = "pending"
    sent = "sent"
    delivered = "delivered"
    read = "read"
    failed = "failed"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(80), default="")
    username: Mapped[str | None] = mapped_column(String(40), unique=True, index=True)
    bio: Mapped[str] = mapped_column(String(160), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)


class LoginCode(Base):
    __tablename__ = "login_codes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone: Mapped[str] = mapped_column(String(32), index=True)
    code_hash: Mapped[str] = mapped_column(String(255))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class SessionToken(Base):
    __tablename__ = "session_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    refresh_hash: Mapped[str] = mapped_column(String(255), unique=True)
    device_name: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)


class Chat(Base):
    __tablename__ = "chats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    type: Mapped[ChatType] = mapped_column(SAEnum(ChatType))
    title: Mapped[str | None] = mapped_column(String(120))
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False)
    is_muted: Mapped[bool] = mapped_column(Boolean, default=False)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    participants: Mapped[list["ChatParticipant"]] = relationship(back_populates="chat", cascade="all, delete-orphan")


class ChatParticipant(Base):
    __tablename__ = "chat_participants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    chat_id: Mapped[int] = mapped_column(ForeignKey("chats.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    role: Mapped[str] = mapped_column(String(20), default="member")
    last_read_message_id: Mapped[int | None] = mapped_column(Integer)
    chat: Mapped[Chat] = relationship(back_populates="participants")


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    chat_id: Mapped[int] = mapped_column(ForeignKey("chats.id"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    kind: Mapped[MessageKind] = mapped_column(SAEnum(MessageKind), default=MessageKind.text)
    text: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[MessageStatus] = mapped_column(SAEnum(MessageStatus), default=MessageStatus.sent)
    reply_to_id: Mapped[int | None] = mapped_column(Integer)
    file_id: Mapped[str | None] = mapped_column(String(80))
    file_name: Mapped[str | None] = mapped_column(String(255))
    mime_type: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, index=True)
    edited_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


Base.metadata.create_all(bind=engine)


class UserProfile(BaseModel):
    id: int
    phone: str
    displayName: str
    username: str | None = None
    bio: str = ""


class AuthSendCodeRequest(BaseModel):
    phone: str = Field(min_length=5, max_length=32)


class AuthVerifyCodeRequest(BaseModel):
    phone: str
    code: str
    displayName: str | None = None
    username: str | None = None
    deviceName: str | None = None


class AuthRefreshRequest(BaseModel):
    refreshToken: str


class AuthTokens(BaseModel):
    accessToken: str
    refreshToken: str
    user: UserProfile


class PatchMeRequest(BaseModel):
    displayName: str | None = None
    username: str | None = None
    bio: str | None = None


class ChatResponse(BaseModel):
    id: int
    type: ChatType
    title: str
    participants: list[UserProfile]
    lastMessage: dict[str, Any] | None
    unreadCount: int
    isMuted: bool
    isPinned: bool
    isArchived: bool
    updatedAt: datetime


class CreatePrivateChatRequest(BaseModel):
    userId: int


class CreateGroupChatRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    participantIds: list[int] = Field(min_length=1)


class PatchChatRequest(BaseModel):
    title: str | None = None
    isMuted: bool | None = None
    isPinned: bool | None = None
    isArchived: bool | None = None


class SendMessageRequest(BaseModel):
    kind: MessageKind = MessageKind.text
    text: str = ""
    replyToId: int | None = None
    fileId: str | None = None
    fileName: str | None = None
    mimeType: str | None = None


class PatchMessageRequest(BaseModel):
    text: str


class UploadResponse(BaseModel):
    fileId: str
    fileName: str
    mimeType: str
    size: int
    url: str


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def user_to_profile(user: User) -> UserProfile:
    return UserProfile(id=user.id, phone=user.phone, displayName=user.display_name, username=user.username, bio=user.bio)


def create_access_token(user_id: int) -> str:
    expires = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_MINUTES)
    return jwt.encode({"sub": str(user_id), "exp": expires}, JWT_SECRET, algorithm="HS256")


def create_refresh_token(db: Session, user_id: int, device_name: str | None) -> str:
    token = secrets.token_urlsafe(48)
    db.add(SessionToken(user_id=user_id, refresh_hash=password_context.hash(token), device_name=device_name))
    return token


def current_user(authorization: Annotated[str | None, Header()] = None, db: Session = Depends(get_db)) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid token")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


def ensure_participant(db: Session, chat_id: int, user_id: int) -> ChatParticipant:
    participant = db.scalar(select(ChatParticipant).where(ChatParticipant.chat_id == chat_id, ChatParticipant.user_id == user_id))
    if not participant:
        raise HTTPException(status_code=404, detail="Chat not found")
    return participant


def message_to_payload(db: Session, message: Message, current_user_id: int) -> dict[str, Any]:
    sender = db.get(User, message.sender_id)
    return {
        "id": message.id,
        "chatId": message.chat_id,
        "sender": user_to_profile(sender).model_dump() if sender else None,
        "kind": message.kind.value,
        "text": "" if message.deleted_at else message.text,
        "status": message.status.value,
        "replyToId": message.reply_to_id,
        "attachment": None if not message.file_id else {
            "fileId": message.file_id,
            "fileName": message.file_name,
            "mimeType": message.mime_type,
            "url": f"/v1/files/{message.file_id}",
        },
        "createdAt": message.created_at,
        "editedAt": message.edited_at,
        "deletedAt": message.deleted_at,
        "outgoing": message.sender_id == current_user_id,
    }


class RealtimeHub:
    def __init__(self) -> None:
        self.connections: dict[int, set[WebSocket]] = {}

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self.connections.setdefault(user_id, set()).add(websocket)

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        self.connections.get(user_id, set()).discard(websocket)

    async def publish(self, user_ids: set[int], event: dict[str, Any]) -> None:
        for user_id in user_ids:
            for ws in list(self.connections.get(user_id, set())):
                try:
                    await ws.send_json(event)
                except RuntimeError:
                    self.disconnect(user_id, ws)


hub = RealtimeHub()
app = FastAPI(title="qnola API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(telegram_router)


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/v1/auth/send-code")
def send_code(request: AuthSendCodeRequest, db: Session = Depends(get_db)):
    code_hash = password_context.hash(DEV_SMS_CODE)
    db.add(LoginCode(phone=request.phone, code_hash=code_hash, expires_at=now_utc() + timedelta(minutes=10)))
    db.commit()
    return {"sent": True, "devCode": DEV_SMS_CODE if os.environ.get("QNOLA_EXPOSE_DEV_CODE", "1") == "1" else None}


@app.post("/v1/auth/verify-code", response_model=AuthTokens)
def verify_code(request: AuthVerifyCodeRequest, db: Session = Depends(get_db)):
    login_code = db.scalar(select(LoginCode).where(LoginCode.phone == request.phone).order_by(LoginCode.id.desc()))
    if not login_code or login_code.expires_at < now_utc() or not password_context.verify(request.code, login_code.code_hash):
        raise HTTPException(status_code=401, detail="Invalid code")
    user = db.scalar(select(User).where(User.phone == request.phone))
    if not user:
        user = User(phone=request.phone, display_name=request.displayName or "qnola user", username=request.username)
        db.add(user)
        db.flush()
    elif request.displayName:
        user.display_name = request.displayName
    if request.username:
        user.username = request.username
    refresh = create_refresh_token(db, user.id, request.deviceName)
    db.commit()
    db.refresh(user)
    return AuthTokens(accessToken=create_access_token(user.id), refreshToken=refresh, user=user_to_profile(user))


@app.post("/v1/auth/refresh", response_model=AuthTokens)
def refresh(request: AuthRefreshRequest, db: Session = Depends(get_db)):
    sessions = db.scalars(select(SessionToken).where(SessionToken.revoked == False)).all()  # noqa: E712
    match = next((s for s in sessions if password_context.verify(request.refreshToken, s.refresh_hash)), None)
    if not match:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = db.get(User, match.user_id)
    refresh_token = create_refresh_token(db, user.id, match.device_name)
    match.revoked = True
    db.commit()
    return AuthTokens(accessToken=create_access_token(user.id), refreshToken=refresh_token, user=user_to_profile(user))


@app.post("/v1/auth/logout")
def logout(user: User = Depends(current_user), db: Session = Depends(get_db)):
    for token in db.scalars(select(SessionToken).where(SessionToken.user_id == user.id)).all():
        token.revoked = True
    db.commit()
    return {}


@app.get("/v1/me", response_model=UserProfile)
def get_me(user: User = Depends(current_user)):
    return user_to_profile(user)


@app.patch("/v1/me", response_model=UserProfile)
def patch_me(request: PatchMeRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if request.displayName is not None:
        user.display_name = request.displayName
    if request.username is not None:
        user.username = request.username
    if request.bio is not None:
        user.bio = request.bio
    db.commit()
    db.refresh(user)
    return user_to_profile(user)


@app.get("/v1/users/search", response_model=list[UserProfile])
def search_users(username: str = Query(min_length=1), user: User = Depends(current_user), db: Session = Depends(get_db)):
    users = db.scalars(select(User).where(User.username.ilike(f"%{username}%"), User.id != user.id).limit(20)).all()
    return [user_to_profile(candidate) for candidate in users]


def chat_payload(db: Session, chat: Chat, user: User) -> ChatResponse:
    participants = [user_to_profile(db.get(User, participant.user_id)) for participant in chat.participants]
    latest = db.scalar(select(Message).where(Message.chat_id == chat.id).order_by(Message.id.desc()))
    current_participant = ensure_participant(db, chat.id, user.id)
    unread = db.scalar(
        select(Message).where(
            Message.chat_id == chat.id,
            Message.sender_id != user.id,
            Message.id > (current_participant.last_read_message_id or 0),
            Message.deleted_at.is_(None),
        )
    )
    title = chat.title or ", ".join(p.displayName for p in participants if p.id != user.id) or "Saved Messages"
    return ChatResponse(
        id=chat.id,
        type=chat.type,
        title=title,
        participants=participants,
        lastMessage=message_to_payload(db, latest, user.id) if latest else None,
        unreadCount=1 if unread else 0,
        isMuted=chat.is_muted,
        isPinned=chat.is_pinned,
        isArchived=chat.is_archived,
        updatedAt=chat.updated_at,
    )


@app.get("/v1/chats", response_model=list[ChatResponse])
def get_chats(user: User = Depends(current_user), db: Session = Depends(get_db)):
    chat_ids = [p.chat_id for p in db.scalars(select(ChatParticipant).where(ChatParticipant.user_id == user.id)).all()]
    chats = db.scalars(select(Chat).where(Chat.id.in_(chat_ids)).order_by(Chat.is_pinned.desc(), Chat.updated_at.desc())).all() if chat_ids else []
    return [chat_payload(db, chat, user) for chat in chats]


@app.post("/v1/chats/private", response_model=ChatResponse)
def create_private_chat(request: CreatePrivateChatRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    other = db.get(User, request.userId)
    if not other:
        raise HTTPException(status_code=404, detail="User not found")
    chat = Chat(type=ChatType.private)
    db.add(chat)
    db.flush()
    db.add_all([ChatParticipant(chat_id=chat.id, user_id=user.id), ChatParticipant(chat_id=chat.id, user_id=other.id)])
    db.commit()
    db.refresh(chat)
    return chat_payload(db, chat, user)


@app.post("/v1/chats/group", response_model=ChatResponse)
def create_group_chat(request: CreateGroupChatRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    participant_ids = sorted(set(request.participantIds + [user.id]))
    users = db.scalars(select(User).where(User.id.in_(participant_ids))).all()
    if len(users) != len(participant_ids):
        raise HTTPException(status_code=404, detail="One or more users were not found")
    chat = Chat(type=ChatType.group, title=request.title)
    db.add(chat)
    db.flush()
    db.add_all([ChatParticipant(chat_id=chat.id, user_id=participant_id) for participant_id in participant_ids])
    db.commit()
    db.refresh(chat)
    return chat_payload(db, chat, user)


@app.patch("/v1/chats/{chat_id}", response_model=ChatResponse)
def patch_chat(chat_id: int, request: PatchChatRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    ensure_participant(db, chat_id, user.id)
    chat = db.get(Chat, chat_id)
    for field in ["title", "isMuted", "isPinned", "isArchived"]:
        value = getattr(request, field)
        if value is not None:
            setattr(chat, {"isMuted": "is_muted", "isPinned": "is_pinned", "isArchived": "is_archived"}.get(field, field), value)
    chat.updated_at = now_utc()
    db.commit()
    db.refresh(chat)
    return chat_payload(db, chat, user)


@app.get("/v1/chats/{chat_id}/messages")
def get_messages(chat_id: int, before: int | None = None, after: int | None = None, limit: int = Query(50, ge=1, le=100), user: User = Depends(current_user), db: Session = Depends(get_db)):
    ensure_participant(db, chat_id, user.id)
    query = select(Message).where(Message.chat_id == chat_id).order_by(Message.id.desc()).limit(limit)
    if before is not None:
        query = select(Message).where(Message.chat_id == chat_id, Message.id < before).order_by(Message.id.desc()).limit(limit)
    if after is not None:
        query = select(Message).where(Message.chat_id == chat_id, Message.id > after).order_by(Message.id.asc()).limit(limit)
    messages = db.scalars(query).all()
    ordered = messages if after is not None else list(reversed(messages))
    return [message_to_payload(db, message, user.id) for message in ordered]


@app.post("/v1/chats/{chat_id}/messages")
async def send_message(chat_id: int, request: SendMessageRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    ensure_participant(db, chat_id, user.id)
    chat = db.get(Chat, chat_id)
    message = Message(
        chat_id=chat_id,
        sender_id=user.id,
        kind=request.kind,
        text=request.text,
        reply_to_id=request.replyToId,
        file_id=request.fileId,
        file_name=request.fileName,
        mime_type=request.mimeType,
    )
    chat.updated_at = now_utc()
    db.add(message)
    db.commit()
    db.refresh(message)
    participant_ids = {participant.user_id for participant in chat.participants}
    payload = message_to_payload(db, message, user.id)
    await hub.publish(participant_ids, {"type": "message.created", "chatId": chat_id, "message": payload})
    return payload


@app.patch("/v1/messages/{message_id}")
async def patch_message(message_id: int, request: PatchMessageRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    message = db.get(Message, message_id)
    if not message or message.sender_id != user.id:
        raise HTTPException(status_code=404, detail="Message not found")
    message.text = request.text
    message.edited_at = now_utc()
    db.commit()
    db.refresh(message)
    return message_to_payload(db, message, user.id)


@app.delete("/v1/messages/{message_id}")
async def delete_message(message_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    message = db.get(Message, message_id)
    if not message or message.sender_id != user.id:
        raise HTTPException(status_code=404, detail="Message not found")
    message.deleted_at = now_utc()
    db.commit()
    return {}


@app.post("/v1/uploads", response_model=UploadResponse)
def upload_file(file: UploadFile = File(...), user: User = Depends(current_user)):
    file_id = secrets.token_urlsafe(18)
    target = MEDIA_ROOT / file_id
    with target.open("wb") as handle:
        shutil.copyfileobj(file.file, handle)
    return UploadResponse(fileId=file_id, fileName=file.filename or file_id, mimeType=file.content_type or "application/octet-stream", size=target.stat().st_size, url=f"/v1/files/{file_id}")


@app.get("/v1/files/{file_id}")
def get_file(file_id: str, user: User = Depends(current_user)):
    target = MEDIA_ROOT / file_id
    if not target.exists():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(target)


@app.websocket("/v1/realtime")
async def realtime(websocket: WebSocket, token: str):
    db = SessionLocal()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        user_id = int(payload["sub"])
        if not db.get(User, user_id):
            await websocket.close(code=4401)
            return
        await hub.connect(user_id, websocket)
        while True:
            event = await websocket.receive_json()
            if event.get("type") in {"typing", "read"}:
                chat_id = int(event.get("chatId"))
                ensure_participant(db, chat_id, user_id)
                participants = db.scalars(select(ChatParticipant).where(ChatParticipant.chat_id == chat_id)).all()
                await hub.publish({p.user_id for p in participants if p.user_id != user_id}, {"type": event["type"], "chatId": chat_id, "userId": user_id})
    except (JWTError, ValueError):
        await websocket.close(code=4401)
    except WebSocketDisconnect:
        pass
    finally:
        hub.disconnect(locals().get("user_id", -1), websocket)
        db.close()
