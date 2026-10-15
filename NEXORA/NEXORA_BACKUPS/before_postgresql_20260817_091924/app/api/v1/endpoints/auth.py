from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)

from app.api.dependencies import get_current_user
from app.repositories.users import UserRecord
from app.schemas.auth import (
    TokenResponse,
    UserLoginRequest,
    UserPublic,
    UserRegisterRequest,
)
from app.services.auth import (
    login_user,
    register_user,
    to_public_user,
)


router = APIRouter(
    prefix="/auth",
    tags=["auth"],
)


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    data: UserRegisterRequest,
) -> TokenResponse:
    try:
        return register_user(data)
    except ValueError as exc:
        code = str(exc)

        if code == "PHONE_ALREADY_REGISTERED":
            detail = (
                "El número de teléfono "
                "ya está registrado"
            )
        elif code == "EMAIL_ALREADY_REGISTERED":
            detail = (
                "El correo electrónico "
                "ya está registrado"
            )
        else:
            detail = "No se pudo crear la cuenta"

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=detail,
        ) from exc


@router.post(
    "/login",
    response_model=TokenResponse,
)
def login(
    data: UserLoginRequest,
) -> TokenResponse:
    result = login_user(data)

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Teléfono o contraseña incorrectos"
            ),
        )

    return result


@router.get(
    "/me",
    response_model=UserPublic,
)
def me(
    current_user: Annotated[
        UserRecord,
        Depends(get_current_user),
    ],
) -> UserPublic:
    return to_public_user(current_user)
