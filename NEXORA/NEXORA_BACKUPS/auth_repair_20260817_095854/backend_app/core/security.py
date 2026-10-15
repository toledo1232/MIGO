import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from jwt.exceptions import InvalidTokenError
from pwdlib import PasswordHash

from app.core.config import settings


password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(
    plain_password: str,
    hashed_password: str,
) -> bool:
    return password_hash.verify(
        plain_password,
        hashed_password,
    )


def create_access_token(
    *,
    subject: str,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    now = datetime.now(timezone.utc)

    expire = now + timedelta(
        minutes=settings.access_token_expire_minutes,
    )

    payload: dict[str, Any] = {
        "sub": subject,
        "iat": now,
        "exp": expire,
        "type": "access",
    }

    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_access_token(
    token: str,
) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[
                settings.jwt_algorithm,
            ],
        )
    except InvalidTokenError as exc:
        raise ValueError(
            "Token invalido"
        ) from exc

    if payload.get("type") != "access":
        raise ValueError(
            "Tipo de token invalido"
        )

    subject = payload.get("sub")

    if not isinstance(subject, str) or not subject:
        raise ValueError(
            "Token sin subject valido"
        )

    return payload


def generate_refresh_token() -> str:
    # 64 bytes aleatorios ~= 512 bits.
    return secrets.token_urlsafe(64)


def hash_refresh_token(
    token: str,
) -> str:
    return hashlib.sha256(
        token.encode("utf-8")
    ).hexdigest()


def refresh_expiration() -> datetime:
    return (
        datetime.now(timezone.utc)
        + timedelta(
            days=settings.refresh_token_expire_days,
        )
    )
