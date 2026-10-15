from app.core.config import settings
from app.core.security import (
    create_access_token,
    hash_password,
    verify_password,
)
from app.repositories.users import (
    UserRecord,
    user_repository,
)
from app.schemas.auth import (
    TokenResponse,
    UserLoginRequest,
    UserPublic,
    UserRegisterRequest,
)


def to_public_user(
    user: UserRecord,
) -> UserPublic:
    return UserPublic(
        id=user.id,
        full_name=user.full_name,
        phone=user.phone,
        email=user.email,
        account_active=user.account_active,
        driver_approved=user.driver_approved,
    )


def build_token_response(
    user: UserRecord,
) -> TokenResponse:
    token = create_access_token(
        subject=user.id,
        extra_claims={
            "account_active":
                user.account_active,
            "driver_approved":
                user.driver_approved,
        },
    )

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in=(
            settings.access_token_expire_minutes
            * 60
        ),
        user=to_public_user(user),
    )


def register_user(
    data: UserRegisterRequest,
) -> TokenResponse:
    user = user_repository.create(
        full_name=data.full_name,
        phone=data.phone,
        email=str(data.email),
        password_hash=hash_password(
            data.password
        ),
    )

    return build_token_response(user)


def login_user(
    data: UserLoginRequest,
) -> TokenResponse | None:
    user = user_repository.get_by_phone(
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

    return build_token_response(user)
