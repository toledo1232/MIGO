from pydantic import BaseModel, EmailStr, Field


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


class UserLoginRequest(BaseModel):
    phone: str = Field(
        min_length=8,
        max_length=20,
    )

    password: str = Field(
        min_length=8,
        max_length=128,
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
    token_type: str = "bearer"
    expires_in: int
    user: UserPublic
