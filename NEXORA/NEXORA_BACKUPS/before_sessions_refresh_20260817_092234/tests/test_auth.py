from uuid import uuid4


def unique_user() -> dict[str, str]:
    suffix = uuid4().hex[:10]

    return {
        "full_name": "Usuario MIGO",
        "phone": f"+519{suffix[:8]}",
        "email": f"{suffix}@migo.test",
        "password": "MigoTest123!",
    }


def test_register_login_and_me(
    client,
) -> None:
    payload = unique_user()

    register_response = client.post(
        "/api/v1/auth/register",
        json=payload,
    )

    assert register_response.status_code == 201

    data = register_response.json()

    assert "access_token" in data
    assert data["user"]["driver_approved"] is False

    token = data["access_token"]

    me_response = client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization":
                f"Bearer {token}",
        },
    )

    assert me_response.status_code == 200

    assert (
        me_response.json()["phone"]
        == payload["phone"]
    )

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "phone": payload["phone"],
            "password": payload["password"],
        },
    )

    assert login_response.status_code == 200


def test_wrong_password_is_rejected(
    client,
) -> None:
    payload = unique_user()

    client.post(
        "/api/v1/auth/register",
        json=payload,
    )

    response = client.post(
        "/api/v1/auth/login",
        json={
            "phone": payload["phone"],
            "password":
                "ContraseñaIncorrecta123!",
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

    assert first.status_code == 201

    second_payload = {
        **payload,
        "email":
            f"otro-{uuid4().hex[:8]}@migo.test",
    }

    second = client.post(
        "/api/v1/auth/register",
        json=second_payload,
    )

    assert second.status_code == 409


def test_me_requires_authentication(
    client,
) -> None:
    response = client.get(
        "/api/v1/auth/me"
    )

    assert response.status_code == 401
