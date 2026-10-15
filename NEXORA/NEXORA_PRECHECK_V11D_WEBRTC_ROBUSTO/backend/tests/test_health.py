from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health_endpoint_returns_ok() -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200

    payload = response.json()

    assert payload["status"] == "ok"
    assert payload["service"] == "migo-drive-api"
    assert payload["version"] == "0.1.0"
    assert "timestamp" in payload


def test_root_returns_api_information() -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json()["message"] == "MIGO DRIVE API"

