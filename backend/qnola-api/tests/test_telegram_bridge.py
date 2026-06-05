from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_telegram_bridge_reports_disabled_without_api_keys():
    state = client.get("/v1/telegram/state")
    assert state.status_code == 200
    assert state.json()["enabled"] is False

    dialogs = client.get("/v1/telegram/dialogs")
    assert dialogs.status_code == 503
