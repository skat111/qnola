from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def register(phone: str, username: str):
    client.post("/v1/auth/send-code", json={"phone": phone})
    response = client.post(
        "/v1/auth/verify-code",
        json={"phone": phone, "code": "111111", "displayName": username, "username": username},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_auth_chat_message_flow():
    alice = register("+10000000001", "alice")
    bob = register("+10000000002", "bob")

    auth = {"Authorization": f"Bearer {alice['accessToken']}"}
    search = client.get("/v1/users/search?username=bob", headers=auth)
    assert search.status_code == 200
    bob_id = search.json()[0]["id"]

    chat = client.post("/v1/chats/private", json={"userId": bob_id}, headers=auth)
    assert chat.status_code == 200, chat.text
    chat_id = chat.json()["id"]

    sent = client.post(f"/v1/chats/{chat_id}/messages", json={"text": "hello", "kind": "text"}, headers=auth)
    assert sent.status_code == 200, sent.text
    assert sent.json()["text"] == "hello"

    messages = client.get(f"/v1/chats/{chat_id}/messages", headers=auth)
    assert messages.status_code == 200
    assert messages.json()[0]["text"] == "hello"

    push = client.post("/v1/devices/push-token", json={"token": "a" * 64, "platform": "ios"}, headers=auth)
    assert push.status_code == 200
    assert push.json()["registered"] is True
