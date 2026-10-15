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


def public_user(
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


def issue_session(
    *,
    db: Session,
    user: User,
    device_name: str | None,
    platform: str | None,
) -> TokenResponse:
    refresh = generate_refresh_token()

    SessionRepository(db).create(
        user_id=user.id,
        token_hash=hash_refresh_token(
            refresh
        ),
        expires_at=refresh_expiration(),
        device_name=device_name,
        platform=platform,
    )

    access = create_access_token(
        subject=str(user.id),
        extra_claims={
            "account_active":
                user.account_active,
            "driver_approved":
                user.driver_approved,
        },
    )

    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        expires_in=(
            settings.access_token_expire_minutes
            * 60
        ),
        user=public_user(user),
    )


def register_user(
    db: Session,
    data: UserRegisterRequest,
) -> TokenResponse:
    user = UserRepository(db).create(
        full_name=data.full_name,
        phone=data.phone,
        email=str(data.email),
        password_hash=hash_password(
            data.password
        ),
    )

    return issue_session(
        db=db,
        user=user,
        device_name=data.device_name,
        platform=data.platform,
    )


def login_user(
    db: Session,
    data: UserLoginRequest,
) -> TokenResponse | None:
    user = UserRepository(
        db
    ).get_by_phone(
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

    return issue_session(
        db=db,
        user=user,
        device_name=data.device_name,
        platform=data.platform,
    )


def refresh_user_session(
    *,
    db: Session,
    raw_token: str,
) -> TokenResponse | None:
    repository = SessionRepository(db)

    item = repository.get_by_hash(
        hash_refresh_token(raw_token)
    )

    if item is None:
        return None

    now = datetime.now(timezone.utc)

    if not item.is_active:
        return None

    if item.expires_at <= now:
        repository.revoke(item)
        return None

    user = item.user

    if not user.account_active:
        repository.revoke(item)
        return None

    new_refresh = generate_refresh_token()

    repository.rotate(
        item=item,
        token_hash=hash_refresh_token(
            new_refresh
        ),
        expires_at=refresh_expiration(),
    )

    access = create_access_token(
        subject=str(user.id),
        extra_claims={
            "account_active":
                user.account_active,
            "driver_approved":
                user.driver_approved,
        },
    )

    return TokenResponse(
        access_token=access,
        refresh_token=new_refresh,
        expires_in=(
            settings.access_token_expire_minutes
            * 60
        ),
        user=public_user(user),
    )


def logout_user_session(
    *,
    db: Session,
    raw_token: str,
) -> None:
    repository = SessionRepository(db)

    item = repository.get_by_hash(
        hash_refresh_token(raw_token)
    )

    if item is not None:
        repository.revoke(item)
