from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field

router = APIRouter(
    prefix="/ride-requests",
    tags=["ride-requests"],
)

_store_lock = asyncio.Lock()
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

    # Snapshot visible para el conductor.
    # La foto del pasajero es OPCIONAL.
    passenger_name: str = Field(
        default="Pasajero MIGO",
        min_length=1,
        max_length=120,
    )
    passenger_photo_base64: str | None = Field(
        default=None,
        max_length=8_000_000,
    )
    passenger_rating: float = Field(default=5.0, ge=0, le=5)
    passenger_trips: int = Field(default=0, ge=0)


class DriverActionRequest(BaseModel):
    # En este prototipo la foto del conductor se envía como snapshot.
    # El cliente no permitirá ponerse DISPONIBLE sin una foto.
    driver_name: str = Field(
        default="Conductor MIGO",
        min_length=1,
        max_length=120,
    )
    driver_photo_base64: str = Field(
        min_length=20,
        max_length=8_000_000,
    )
    driver_rating: float = Field(default=5.0, ge=0, le=5)
    driver_trips: int = Field(default=0, ge=0)
    vehicle_model: str = Field(
        default="Vehículo por configurar",
        min_length=1,
        max_length=120,
    )
    vehicle_plate: str = Field(
        default="Por registrar",
        min_length=1,
        max_length=40,
    )
    vehicle_color: str = Field(
        default="Por registrar",
        min_length=1,
        max_length=60,
    )


class CounterOfferRequest(DriverActionRequest):
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

    passenger_name: str
    passenger_photo_base64: str | None = None
    passenger_rating: float
    passenger_trips: int

    driver_name: str | None = None
    driver_photo_base64: str | None = None
    driver_rating: float | None = None
    driver_trips: int | None = None
    vehicle_model: str | None = None
    vehicle_plate: str | None = None
    vehicle_color: str | None = None

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
        passenger_name=item["passenger_name"],
        passenger_photo_base64=item.get("passenger_photo_base64"),
        passenger_rating=item["passenger_rating"],
        passenger_trips=item["passenger_trips"],
        driver_name=item.get("driver_name"),
        driver_photo_base64=item.get("driver_photo_base64"),
        driver_rating=item.get("driver_rating"),
        driver_trips=item.get("driver_trips"),
        vehicle_model=item.get("vehicle_model"),
        vehicle_plate=item.get("vehicle_plate"),
        vehicle_color=item.get("vehicle_color"),
        created_at=item["created_at"],
        updated_at=item["updated_at"],
    )


def _payload(item: dict) -> dict:
    return _serialize(item).model_dump()


def _get_item(request_id: str) -> dict:
    item = _requests.get(request_id)

    if item is None:
        raise HTTPException(
            status_code=404,
            detail="Solicitud no encontrada.",
        )

    return item


def _apply_driver_profile(
    item: dict,
    payload: DriverActionRequest,
) -> None:
    item["driver_name"] = payload.driver_name.strip()
    item["driver_photo_base64"] = payload.driver_photo_base64
    item["driver_rating"] = float(payload.driver_rating)
    item["driver_trips"] = int(payload.driver_trips)
    item["vehicle_model"] = payload.vehicle_model.strip()
    item["vehicle_plate"] = payload.vehicle_plate.strip()
    item["vehicle_color"] = payload.vehicle_color.strip()


class RideRealtimeManager:
    def __init__(self) -> None:
        self._drivers: set[WebSocket] = set()
        self._requests: dict[str, set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect_driver(self, websocket: WebSocket) -> None:
        await websocket.accept()

        async with self._lock:
            self._drivers.add(websocket)

    async def disconnect_driver(self, websocket: WebSocket) -> None:
        async with self._lock:
            self._drivers.discard(websocket)

    async def connect_request(
        self,
        request_id: str,
        websocket: WebSocket,
    ) -> None:
        await websocket.accept()

        async with self._lock:
            sockets = self._requests.setdefault(request_id, set())
            sockets.add(websocket)

    async def disconnect_request(
        self,
        request_id: str,
        websocket: WebSocket,
    ) -> None:
        async with self._lock:
            sockets = self._requests.get(request_id)

            if sockets is None:
                return

            sockets.discard(websocket)

            if not sockets:
                self._requests.pop(request_id, None)

    async def _send_many(
        self,
        sockets: list[WebSocket],
        message: dict,
    ) -> list[WebSocket]:
        dead: list[WebSocket] = []

        for websocket in sockets:
            try:
                await websocket.send_json(message)
            except Exception:
                dead.append(websocket)

        return dead

    async def broadcast_drivers(self, message: dict) -> None:
        async with self._lock:
            sockets = list(self._drivers)

        dead = await self._send_many(sockets, message)

        if dead:
            async with self._lock:
                for websocket in dead:
                    self._drivers.discard(websocket)

    async def broadcast_request(
        self,
        request_id: str,
        message: dict,
    ) -> None:
        async with self._lock:
            sockets = list(self._requests.get(request_id, set()))

        dead = await self._send_many(sockets, message)

        if dead:
            async with self._lock:
                current = self._requests.get(request_id)

                if current is not None:
                    for websocket in dead:
                        current.discard(websocket)

                    if not current:
                        self._requests.pop(request_id, None)


realtime = RideRealtimeManager()


async def _notify_updated(item: dict) -> None:
    await realtime.broadcast_request(
        item["id"],
        {
            "event": "ride_updated",
            "ride": _payload(item),
        },
    )


async def _notify_removed(
    item: dict,
    *,
    reason: str,
) -> None:
    await realtime.broadcast_drivers(
        {
            "event": "ride_removed",
            "request_id": item["id"],
            "reason": reason,
        },
    )

    await _notify_updated(item)


@router.websocket("/ws/drivers")
async def driver_events(websocket: WebSocket) -> None:
    await realtime.connect_driver(websocket)

    try:
        async with _store_lock:
            pending = [
                _payload(item)
                for item in _requests.values()
                if item["status"] == "searching"
            ]

        await websocket.send_json(
            {
                "event": "pending_snapshot",
                "rides": pending,
            },
        )

        while True:
            # El cliente puede enviar ping. No necesitamos procesar el contenido.
            await websocket.receive_text()

    except WebSocketDisconnect:
        pass
    finally:
        await realtime.disconnect_driver(websocket)


@router.websocket("/ws/request/{request_id}")
async def request_events(
    request_id: str,
    websocket: WebSocket,
) -> None:
    await realtime.connect_request(request_id, websocket)

    try:
        async with _store_lock:
            item = _requests.get(request_id)
            snapshot = _payload(item) if item is not None else None

        if snapshot is not None:
            await websocket.send_json(
                {
                    "event": "ride_updated",
                    "ride": snapshot,
                },
            )

        while True:
            await websocket.receive_text()

    except WebSocketDisconnect:
        pass
    finally:
        await realtime.disconnect_request(request_id, websocket)


@router.post(
    "",
    response_model=RideRequestResponse,
    status_code=201,
)
async def create_ride_request(
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
        "passenger_name": payload.passenger_name.strip(),
        "passenger_photo_base64": payload.passenger_photo_base64,
        "passenger_rating": float(payload.passenger_rating),
        "passenger_trips": int(payload.passenger_trips),
        "driver_name": None,
        "driver_photo_base64": None,
        "driver_rating": None,
        "driver_trips": None,
        "vehicle_model": None,
        "vehicle_plate": None,
        "vehicle_color": None,
        "created_at": now,
        "updated_at": now,
    }

    async with _store_lock:
        _requests[request_id] = item

    await realtime.broadcast_drivers(
        {
            "event": "ride_created",
            "ride": _payload(item),
        },
    )

    return _serialize(item)


@router.get(
    "/pending",
    response_model=list[RideRequestResponse],
)
async def pending_ride_requests() -> list[RideRequestResponse]:
    async with _store_lock:
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
async def get_ride_request(
    request_id: str,
) -> RideRequestResponse:
    async with _store_lock:
        return _serialize(_get_item(request_id))


@router.post(
    "/{request_id}/cancel",
    response_model=RideRequestResponse,
)
async def cancel_ride_request(
    request_id: str,
) -> RideRequestResponse:
    changed = False

    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] in {
            "searching",
            "counter_offer",
        }:
            item["status"] = "cancelled"
            item["updated_at"] = _now()
            changed = True

        response = _serialize(item)

    if changed:
        await _notify_removed(item, reason="cancelled")

    return response


@router.post(
    "/{request_id}/accept",
    response_model=RideRequestResponse,
)
async def driver_accept(
    request_id: str,
    payload: DriverActionRequest,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "searching":
            raise HTTPException(
                status_code=409,
                detail="La solicitud ya no está disponible.",
            )

        _apply_driver_profile(item, payload)
        item["status"] = "accepted"
        item["driver_offer"] = None
        item["updated_at"] = _now()

        response = _serialize(item)

    await _notify_removed(item, reason="accepted")

    return response


@router.post(
    "/{request_id}/counter",
    response_model=RideRequestResponse,
)
async def driver_counter_offer(
    request_id: str,
    payload: CounterOfferRequest,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "searching":
            raise HTTPException(
                status_code=409,
                detail="La solicitud ya no está disponible.",
            )

        _apply_driver_profile(item, payload)
        item["driver_offer"] = round(float(payload.offer), 2)
        item["status"] = "counter_offer"
        item["updated_at"] = _now()

        response = _serialize(item)

    await _notify_removed(item, reason="counter_offer")

    return response


@router.post(
    "/{request_id}/counter/accept",
    response_model=RideRequestResponse,
)
async def passenger_accept_counter(
    request_id: str,
) -> RideRequestResponse:
    async with _store_lock:
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

        response = _serialize(item)

    await _notify_removed(item, reason="accepted")

    return response


@router.post(
    "/{request_id}/counter/reject",
    response_model=RideRequestResponse,
)
async def passenger_reject_counter(
    request_id: str,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "counter_offer":
            raise HTTPException(
                status_code=409,
                detail="No existe una contraoferta activa.",
            )

        item["driver_offer"] = None
        item["driver_name"] = None
        item["driver_photo_base64"] = None
        item["driver_rating"] = None
        item["driver_trips"] = None
        item["vehicle_model"] = None
        item["vehicle_plate"] = None
        item["vehicle_color"] = None
        item["status"] = "searching"
        item["updated_at"] = _now()

        response = _serialize(item)

    await realtime.broadcast_drivers(
        {
            "event": "ride_created",
            "ride": _payload(item),
        },
    )
    await _notify_updated(item)

    return response
