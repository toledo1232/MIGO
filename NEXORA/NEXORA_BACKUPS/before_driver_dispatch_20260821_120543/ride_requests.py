from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from uuid import uuid4

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(
    prefix="/ride-requests",
    tags=["ride-requests"],
)

_store_lock = Lock()
_requests: dict[str, dict] = {}


class CreateRideRequest(BaseModel):
    offer: float = Field(ge=3, le=500)


class RideRequestResponse(BaseModel):
    id: str
    status: str
    offer: float
    created_at: str
    updated_at: str


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _serialize(item: dict) -> RideRequestResponse:
    return RideRequestResponse(
        id=item["id"],
        status=item["status"],
        offer=item["offer"],
        created_at=item["created_at"],
        updated_at=item["updated_at"],
    )


@router.post(
    "",
    response_model=RideRequestResponse,
    status_code=201,
)
def create_ride_request(
    payload: CreateRideRequest,
) -> RideRequestResponse:
    now = _now()
    request_id = str(uuid4())

    item = {
        "id": request_id,
        "status": "searching",
        "offer": round(float(payload.offer), 2),
        "created_at": now,
        "updated_at": now,
    }

    with _store_lock:
        _requests[request_id] = item

    return _serialize(item)


@router.get(
    "/pending",
    response_model=list[RideRequestResponse],
)
def pending_ride_requests() -> list[RideRequestResponse]:
    with _store_lock:
        items = [
            _serialize(item)
            for item in _requests.values()
            if item["status"] == "searching"
        ]

    return items


@router.get(
    "/{request_id}",
    response_model=RideRequestResponse,
)
def get_ride_request(
    request_id: str,
) -> RideRequestResponse:
    with _store_lock:
        item = _requests.get(request_id)

        if item is None:
            raise HTTPException(
                status_code=404,
                detail="Solicitud no encontrada.",
            )

        return _serialize(item)


@router.post(
    "/{request_id}/cancel",
    response_model=RideRequestResponse,
)
def cancel_ride_request(
    request_id: str,
) -> RideRequestResponse:
    with _store_lock:
        item = _requests.get(request_id)

        if item is None:
            raise HTTPException(
                status_code=404,
                detail="Solicitud no encontrada.",
            )

        if item["status"] == "searching":
            item["status"] = "cancelled"
            item["updated_at"] = _now()

        return _serialize(item)
