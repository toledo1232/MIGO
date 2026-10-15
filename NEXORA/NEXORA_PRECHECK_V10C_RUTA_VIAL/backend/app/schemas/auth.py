from pydantic import (
    BaseModel,
    EmailStr,
    Field,
)


class UserRegisterRequest(BaseModel):
    full_name: str = Field(
        min_length=3,
        max_length=120,
    )

    phone: str = Field(
        min_length=8,
        max_length=20,
    )

    email: EmailStr

    password: str = Field(
        min_length=8,
        max_length=128,
    )

    device_name: str | None = Field(
        default=None,
        max_length=120,
    )

    platform: str | None = Field(
        default=None,
        max_length=40,
    )


class UserLoginRequest(BaseModel):
    phone: str = Field(
        min_length=8,
        max_length=20,
    )

    password: str = Field(
        min_length=8,
        max_length=128,
    )

    device_name: str | None = Field(
        default=None,
        max_length=120,
    )

    platform: str | None = Field(
        default=None,
        max_length=40,
    )


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(
        min_length=40,
        max_length=512,
    )


class LogoutRequest(BaseModel):
    refresh_token: str = Field(
        min_length=40,
        max_length=512,
    )


class UserPublic(BaseModel):
    id: str
    full_name: str
    phone: str
    email: str
    account_active: bool
    driver_approved: bool


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserPublic


class SessionPublic(BaseModel):
    id: str
    device_name: str | None
    platform: str | None
    is_active: bool
    created_at: str
    last_used_at: str
    expires_at: str