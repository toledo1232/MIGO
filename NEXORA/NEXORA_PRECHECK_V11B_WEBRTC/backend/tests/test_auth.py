from random import randint


def unique_user() -> dict[str, str]:
    number = randint(
        900000000,
        999999999,
    )

    return {
        "full_name": "Usuario MIGO Prueba",
        "phone": str(number),
        "email": f"migo{number}@example.com",
        "password": "MigoTest123!",
        "device_name": "Pytest Device",
        "platform": "test",
    }


def test_register_login_and_me(
    client,
) -> None:
    payload = unique_user()

    register_response = client.post(
        "/api/v1/auth/register",
        json=payload,
    )

    assert (
        register_response.status_code == 201
    ), register_response.text

    data = register_response.json()

    assert "access_token" in data
    assert "refresh_token" in data
    assert "user" in data

    assert (
        data["user"]["driver_approved"]
        is False
    )

    token = data["access_token"]

    me_response = client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization":
                f"Bearer {token}",
        },
    )

    assert (
        me_response.status_code == 200
    ), me_response.text

    assert (
        me_response.json()["phone"]
        == payload["phone"]
    )

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "phone": payload["phone"],
            "password": payload["password"],
            "device_name": "Pytest Device",
            "platform": "test",
        },
    )

    assert (
        login_response.status_code == 200
    ), login_response.text

    login_data = login_response.json()

    assert "access_token" in login_data
    assert "refresh_token" in login_data


def test_wrong_password_is_rejected(
    client,
) -> None:
    payload = unique_user()

    register_response = client.post(
        "/api/v1/auth/register",
        json=payload,
    )

    assert (
        register_response.status_code == 201
    ), register_response.text

    response = client.post(
        "/api/v1/auth/login",
        json={
            "phone": payload["phone"],
            "password":
                "PasswordIncorrecta123!",
            "device_name": "Pytest Device",
            "platform": "test",
        },
    )

    assert response.status_code == 401


def test_duplicate_phone_is_rejected(
    client,
) -> None:
    payload = unique_user()

    first = client.post(
        "/api/v1/auth/register",
        json=payload,
    )

    assert (
        first.status_code == 201
    ), first.text

    another_number = randint(
        900000000,
        999999999,
    )

    duplicate = {
        **payload,
        "email":
            f"otro{another_number}@example.com",
    }

    second = client.post(
        "/api/v1/auth/register",
        json=duplicate,
    )

    assert second.status_code == 409


def test_me_requires_authentication(
    client,
) -> None:
    response = client.get(
        "/api/v1/auth/me"
    )

    assert response.status_code == 401