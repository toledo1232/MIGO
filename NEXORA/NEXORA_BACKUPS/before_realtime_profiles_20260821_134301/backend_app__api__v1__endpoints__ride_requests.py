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
    pickup_text: str = Field(
        default="Recogida no especificada",
        min_length=1,
        max_length=240,
    )
    destination_text: str = Field(
        default="Destino no especificado",
        min_length=1,
        max_length=240,
    )
    payment_method: str = Field(
        default="Efectivo",
        min_length=1,
        max_length=40,
    )
    pickup_lat: float | None = Field(default=None, ge=-90, le=90)
    pickup_lng: float | None = Field(default=None, ge=-180, le=180)
    destination_lat: float | None = Field(default=None, ge=-90, le=90)
    destination_lng: float | None = Field(default=None, ge=-180, le=180)


class CounterOfferRequest(BaseModel):
    offer: float = Field(ge=3, le=500)


class RideRequestResponse(BaseModel):
    id: str
    status: str
    offer: float
    driver_offer: float | None = None
    pickup_text: str
    destination_text: str
    payment_method: str
    pickup_lat: float | None = None
    pickup_lng: float | None = None
    destination_lat: float | None = None
    destination_lng: float | None = None
    created_at: str
    updated_at: str


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _serialize(item: dict) -> RideRequestResponse:
    return RideRequestResponse(
        id=item["id"],
        status=item["status"],
        offer=item["offer"],
        driver_offer=item.get("driver_offer"),
        pickup_text=item["pickup_text"],
        destination_text=item["destination_text"],
        payment_method=item["payment_method"],
        pickup_lat=item.get("pickup_lat"),
        pickup_lng=item.get("pickup_lng"),
        destination_lat=item.get("destination_lat"),
        destination_lng=item.get("destination_lng"),
        created_at=item["created_at"],
        updated_at=item["updated_at"],
    )


def _get_item(request_id: str) -> dict:
    item = _requests.get(request_id)

    if item is None:
        raise HTTPException(
            status_code=404,
            detail="Solicitud no encontrada.",
        )

    return item


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
        "driver_offer": None,
        "pickup_text": payload.pickup_text.strip(),
        "destination_text": payload.destination_text.strip(),
        "payment_method": payload.payment_method.strip(),
        "pickup_lat": payload.pickup_lat,
        "pickup_lng": payload.pickup_lng,
        "destination_lat": payload.destination_lat,
        "destination_lng": payload.destination_lng,
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
        return _serialize(_get_item(request_id))


@router.post(
    "/{request_id}/cancel",
    response_model=RideRequestResponse,
)
def cancel_ride_request(
    request_id: str,
) -> RideRequestResponse:
    with _store_lock:
        item = _get_item(request_id)

        if item["status"] in {
            "searching",
            "counter_offer",
        }:
            item["status"] = "cancelled"
            item["updated_at"] = _now()

        return _serialize(item)


@router.post(
    "/{request_id}/accept",
    response_model=RideRequestResponse,
)
def driver_accept(
    request_id: str,
) -> RideRequestResponse:
    with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "searching":
            raise HTTPException(
                status_code=409,
                detail="La solicitud ya no está disponible.",
            )

        item["status"] = "accepted"
        item["driver_offer"] = None
        item["updated_at"] = _now()

        return _serialize(item)


@router.post(
    "/{request_id}/counter",
    response_model=RideRequestResponse,
)
def driver_counter_offer(
    request_id: str,
    payload: CounterOfferRequest,
) -> RideRequestResponse:
    with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "searching":
            raise HTTPException(
                status_code=409,
                detail="La solicitud ya no está disponible.",
            )

        item["driver_offer"] = round(float(payload.offer), 2)
        item["status"] = "counter_offer"
        item["updated_at"] = _now()

        return _serialize(item)


@router.post(
    "/{request_id}/counter/accept",
    response_model=RideRequestResponse,
)
def passenger_accept_counter(
    request_id: str,
) -> RideRequestResponse:
    with _store_lock:
        item = _get_item(request_id)

        if (
            item["status"] != "counter_offer"
            or item.get("driver_offer") is None
        ):
            raise HTTPException(
                status_code=409,
                detail="No existe una contraoferta activa.",
            )

        item["offer"] = item["driver_offer"]
        item["status"] = "accepted"
        item["updated_at"] = _now()

        return _serialize(item)


@router.post(
    "/{request_id}/counter/reject",
    response_model=RideRequestResponse,
)
def passenger_reject_counter(
    request_id: str,
) -> RideRequestResponse:
    with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "counter_offer":
            raise HTTPException(
                status_code=409,
                detail="No existe una contraoferta activa.",
            )

        item["driver_offer"] = None
        item["status"] = "searching"
        item["updated_at"] = _now()

        return _serialize(item)
