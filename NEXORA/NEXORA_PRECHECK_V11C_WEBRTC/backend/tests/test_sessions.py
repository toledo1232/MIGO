from random import randint


def new_user() -> dict[str, str]:
    number = randint(
        900000000,
        999999999,
    )

    return {
        "full_name":
            "Usuario Sesion MIGO",
        "phone": str(number),
        "email":
            f"session{number}@example.com",
        "password":
            "MigoSession123!",
        "device_name":
            "Pixel 8 Test",
        "platform":
            "android",
    }


def register_user(client):
    payload = new_user()

    response = client.post(
        "/api/v1/auth/register",
        json=payload,
    )

    assert (
        response.status_code == 201
    ), response.text

    return payload, response.json()


def test_login_returns_refresh_token(
    client,
) -> None:
    payload, registered = register_user(
        client
    )

    assert "access_token" in registered
    assert "refresh_token" in registered

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "phone": payload["phone"],
            "password":
                payload["password"],
            "device_name":
                "Pixel 8 Test",
            "platform":
                "android",
        },
    )

    assert (
        login_response.status_code == 200
    ), login_response.text

    data = login_response.json()

    assert data["access_token"]
    assert data["refresh_token"]


def test_refresh_rotates_token(
    client,
) -> None:
    _, data = register_user(client)

    old_refresh = data[
        "refresh_token"
    ]

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={
            "refresh_token":
                old_refresh,
        },
    )

    assert (
        refresh_response.status_code
        == 200
    ), refresh_response.text

    refreshed = (
        refresh_response.json()
    )

    new_refresh = refreshed[
        "refresh_token"
    ]

    assert new_refresh != old_refresh

    reuse = client.post(
        "/api/v1/auth/refresh",
        json={
            "refresh_token":
                old_refresh,
        },
    )

    assert reuse.status_code == 401


def test_logout_revokes_refresh(
    client,
) -> None:
    _, data = register_user(client)

    refresh_token = data[
        "refresh_token"
    ]

    logout_response = client.post(
        "/api/v1/auth/logout",
        json={
            "refresh_token":
                refresh_token,
        },
    )

    assert (
        logout_response.status_code
        == 204
    )

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={
            "refresh_token":
                refresh_token,
        },
    )

    assert (
        refresh_response.status_code
        == 401
    )


def test_sessions_endpoint(
    client,
) -> None:
    _, data = register_user(client)

    access_token = data[
        "access_token"
    ]

    response = client.get(
        "/api/v1/auth/sessions",
        headers={
            "Authorization":
                f"Bearer {access_token}",
        },
    )

    assert (
        response.status_code == 200
    ), response.text

    sessions = response.json()

    assert len(sessions) >= 1