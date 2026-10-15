from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Response,
    status,
)
from sqlalchemy.orm import Session

from app.api.dependencies import (
    get_current_user,
    get_db,
)
from app.models.user import User
from app.repositories.sessions import (
    SessionRepository,
)
from app.schemas.auth import (
    LogoutRequest,
    RefreshTokenRequest,
    SessionPublic,
    TokenResponse,
    UserLoginRequest,
    UserPublic,
    UserRegisterRequest,
)
from app.services.auth import (
    login_user,
    logout_user_session,
    public_user,
    refresh_user_session,
    register_user,
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
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> TokenResponse:
    try:
        return register_user(
            db,
            data,
        )

    except ValueError as exc:
        code = str(exc)

        if code == "PHONE_ALREADY_REGISTERED":
            detail = (
                "El numero de telefono "
                "ya esta registrado"
            )

        elif code == "EMAIL_ALREADY_REGISTERED":
            detail = (
                "El correo electronico "
                "ya esta registrado"
            )

        else:
            detail = (
                "No se pudo crear la cuenta"
            )

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
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> TokenResponse:
    result = login_user(
        db,
        data,
    )

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Telefono o contrasena incorrectos"
            ),
        )

    return result


@router.post(
    "/refresh",
    response_model=TokenResponse,
)
def refresh(
    data: RefreshTokenRequest,
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> TokenResponse:
    result = refresh_user_session(
        db=db,
        raw_token=data.refresh_token,
    )

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Sesion expirada o invalida"
            ),
        )

    return result


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
)
def logout(
    data: LogoutRequest,
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> Response:
    logout_user_session(
        db=db,
        raw_token=data.refresh_token,
    )

    return Response(
        status_code=status.HTTP_204_NO_CONTENT
    )


@router.get(
    "/me",
    response_model=UserPublic,
)
def me(
    current_user: Annotated[
        User,
        Depends(get_current_user),
    ],
) -> UserPublic:
    return public_user(
        current_user
    )


@router.get(
    "/sessions",
    response_model=list[SessionPublic],
)
def sessions(
    current_user: Annotated[
        User,
        Depends(get_current_user),
    ],
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> list[SessionPublic]:

    items = SessionRepository(
        db
    ).list_for_user(
        current_user.id
    )

    return [
        SessionPublic(
            id=str(item.id),
            device_name=item.device_name,
            platform=item.platform,
            is_active=item.is_active,
            created_at=(
                item.created_at.isoformat()
            ),
            last_used_at=(
                item.last_used_at.isoformat()
            ),
            expires_at=(
                item.expires_at.isoformat()
            ),
        )
        for item in items
    ]


@router.post(
    "/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
)
def logout_all(
    current_user: Annotated[
        User,
        Depends(get_current_user),
    ],
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> Response:

    SessionRepository(
        db
    ).revoke_all_for_user(
        current_user.id
    )

    return Response(
        status_code=status.HTTP_204_NO_CONTENT
    )