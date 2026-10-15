from datetime import UTC, datetime
from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel


router = APIRouter()


class HealthResponse(BaseModel):
    status: Literal["ok"]
    service: str
    version: str
    timestamp: datetime


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Comprobar el estado de MIGO DRIVE",
)
def health_check() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="migo-drive-api",
        version="0.1.0",
        timestamp=datetime.now(UTC),
    )

