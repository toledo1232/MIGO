from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_register_login_and_me() -> None:
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Usuario Prueba",
            "phone": "+51999900001",
            "email": "test1@migo.local",
            "password": "MigoTest123!",
        },
    )

    assert register_response.status_code == 201

    register_data = register_response.json()

    assert "access_token" in register_data
    assert (
        register_data["token_type"]
        == "bearer"
    )

    assert (
        register_data["user"][
            "driver_approved"
        ]
        is False
    )

    access_token = register_data[
        "access_token"
    ]

    me_response = client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization":
                f"Bearer {access_token}",
        },
    )

    assert me_response.status_code == 200

    me_data = me_response.json()

    assert (
        me_data["phone"]
        == "+51999900001"
    )

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "phone": "+51999900001",
            "password": "MigoTest123!",
        },
    )

    assert login_response.status_code == 200

    assert (
        "access_token"
        in login_response.json()
    )


def test_wrong_password_is_rejected() -> None:
    client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Usuario Dos",
            "phone": "+51999900002",
            "email": "test2@migo.local",
            "password": "MigoTest123!",
        },
    )

    response = client.post(
        "/api/v1/auth/login",
        json={
            "phone": "+51999900002",
            "password": "ContraseñaIncorrecta123!",
        },
    )

    assert response.status_code == 401


def test_duplicate_phone_is_rejected() -> None:
    payload = {
        "full_name": "Usuario Tres",
        "phone": "+51999900003",
        "email": "test3@migo.local",
        "password": "MigoTest123!",
    }

    first = client.post(
        "/api/v1/auth/register",
        json=payload,
    )

    assert first.status_code == 201

    duplicate_payload = {
        **payload,
        "email": "otro@migo.local",
    }

    second = client.post(
        "/api/v1/auth/register",
        json=duplicate_payload,
    )

    assert second.status_code == 409


def test_me_requires_authentication() -> None:
    response = client.get(
        "/api/v1/auth/me"
    )

    assert response.status_code == 401
