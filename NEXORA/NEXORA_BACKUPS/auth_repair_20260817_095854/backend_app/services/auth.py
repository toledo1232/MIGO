from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    refresh_expiration,
    verify_password,
)
from app.models.user import User
from app.repositories.sessions import (
    SessionRepository,
)
from app.repositories.users import (
    UserRepository,
)
from app.schemas.auth import (
    TokenResponse,
    UserLoginRequest,
    UserPublic,
    UserRegisterRequest,
)


def to_public_user(
    user: User,
) -> UserPublic:
    return UserPublic(
        id=str(user.id),
        full_name=user.full_name,
        phone=user.phone,
        email=user.email,
        account_active=user.account_active,
        driver_approved=user.driver_approved,
    )


def create_session_tokens(
    *,
    db: Session,
    user: User,
    device_name: str | None,
    platform: str | None,
) -> TokenResponse:
    raw_refresh_token = (
        generate_refresh_token()
    )

    SessionRepository(db).create(
        user_id=user.id,
        refresh_token_hash=hash_refresh_token(
            raw_refresh_token
        ),
        expires_at=refresh_expiration(),
        device_name=device_name,
        platform=platform,
    )

    access_token = create_access_token(
        subject=str(user.id),
        extra_claims={
            "account_active":
                user.account_active,
            "driver_approved":
                user.driver_approved,
        },
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        token_type="bearer",
        expires_in=(
            settings.access_token_expire_minutes
            * 60
        ),
        user=to_public_user(user),
    )


def register_user(
    db: Session,
    data: UserRegisterRequest,
) -> TokenResponse:
    repository = UserRepository(db)

    user = repository.create(
        full_name=data.full_name,
        phone=data.phone,
        email=str(data.email),
        password_hash=hash_password(
            data.password
        ),
    )

    return create_session_tokens(
        db=db,
        user=user,
        device_name=data.device_name,
        platform=data.platform,
    )


def login_user(
    db: Session,
    data: UserLoginRequest,
) -> TokenResponse | None:
    repository = UserRepository(db)

    user = repository.get_by_phone(
        data.phone
    )

    if user is None:
        return None

    if not user.account_active:
        return None

    if not verify_password(
        data.password,
        user.password_hash,
    ):
        return None

    return create_session_tokens(
        db=db,
        user=user,
        device_name=data.device_name,
        platform=data.platform,
    )


def refresh_session(
    *,
    db: Session,
    raw_refresh_token: str,
) -> TokenResponse | None:
    sessions = SessionRepository(db)

    token_hash = hash_refresh_token(
        raw_refresh_token
    )

    session = sessions.get_by_token_hash(
        token_hash
    )

    if session is None:
        return None

    now = datetime.now(timezone.utc)

    if not session.is_active:
        return None

    if session.expires_at <= now:
        sessions.revoke(session)
        return None

    user = session.user

    if not user.account_active:
        sessions.revoke(session)
        return None

    new_refresh_token = (
        generate_refresh_token()
    )

    sessions.rotate(
        session=session,
        new_token_hash=hash_refresh_token(
            new_refresh_token
        ),
        new_expires_at=refresh_expiration(),
    )

    access_token = create_access_token(
        subject=str(user.id),
        extra_claims={
            "account_active":
                user.account_active,
            "driver_approved":
                user.driver_approved,
        },
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        token_type="bearer",
        expires_in=(
            settings.access_token_expire_minutes
            * 60
        ),
        user=to_public_user(user),
    )


def logout_session(
    *,
    db: Session,
    raw_refresh_token: str,
) -> bool:
    sessions = SessionRepository(db)

    session = sessions.get_by_token_hash(
        hash_refresh_token(
            raw_refresh_token
        )
    )

    if session is None:
        return False

    sessions.revoke(session)

    return True
