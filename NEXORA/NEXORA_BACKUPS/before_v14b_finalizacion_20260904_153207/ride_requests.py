from __future__ import annotations

import asyncio
import math
from datetime import datetime, timezone
from typing import Literal
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


class DriverLocationUpdate(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class RideMessageRequest(BaseModel):
    actor: Literal["passenger", "driver"]
    text: str = Field(default="", max_length=500)
    kind: Literal["text", "image", "audio"] = "text"
    media_base64: str | None = Field(default=None, max_length=2_500_000)
    media_mime: str | None = Field(default=None, max_length=80)
    duration_ms: int | None = Field(default=None, ge=0, le=60_000)


class SafetyAlertRequest(BaseModel):
    actor: Literal["passenger", "driver"]
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class CompletionRequest(BaseModel):
    actor: Literal["passenger", "driver"] = "driver"
    reason: str | None = Field(default=None, max_length=240)


class CancelRideRequest(BaseModel):
    actor: Literal["passenger", "driver"] = "passenger"
    reason: str = Field(default="other", min_length=1, max_length=80)
    details: str | None = Field(default=None, max_length=500)


class VoiceCallStartRequest(BaseModel):
    actor: Literal["passenger", "driver"]


class VoiceCallActionRequest(BaseModel):
    actor: Literal["passenger", "driver"]
    action: Literal["accept", "reject", "end"]


class VoiceCallSignalRequest(BaseModel):
    actor: Literal["passenger", "driver"]
    signal_type: Literal["offer", "answer", "candidate"]
    payload: dict = Field(default_factory=dict)


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

    driver_lat: float | None = None
    driver_lng: float | None = None
    driver_location_updated_at: str | None = None

    passenger_live_lat: float | None = None
    passenger_live_lng: float | None = None
    passenger_location_updated_at: str | None = None

    accepted_at: str | None = None
    arrived_at: str | None = None
    started_at: str | None = None
    completed_at: str | None = None
    arrival_reported_at: str | None = None
    arrival_reported_by: str | None = None
    completion_problem: bool = False
    completion_requested_at: str | None = None
    completion_requested_by: str | None = None
    completion_reason: str | None = None
    completion_near_destination: bool = False
    completion_confirmed_by: str | None = None

    cancelled_at: str | None = None
    cancelled_by: str | None = None
    cancellation_reason: str | None = None
    cancellation_details: str | None = None
    cancellation_status_code: str | None = None
    cancellation_reason_label: str | None = None
    cancellation_previous_status: str | None = None
    cancellation_stage: str | None = None
    cancellation_review_required: bool = False
    cancellation_admin_status: str = "not_required"
    cancellation_credit_policy: str = "none"
    cancellation_credit_message: str | None = None

    credits_reserved: int = 0
    credits_status: str = "none"
    credits_consumed: int = 0

    sos_active: bool = False
    sos_last_actor: str | None = None
    sos_last_at: str | None = None

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
        driver_lat=item.get("driver_lat"),
        driver_lng=item.get("driver_lng"),
        driver_location_updated_at=item.get("driver_location_updated_at"),
        passenger_live_lat=item.get("passenger_live_lat"),
        passenger_live_lng=item.get("passenger_live_lng"),
        passenger_location_updated_at=item.get("passenger_location_updated_at"),
        accepted_at=item.get("accepted_at"),
        arrived_at=item.get("arrived_at"),
        started_at=item.get("started_at"),
        completed_at=item.get("completed_at"),
        arrival_reported_at=item.get("arrival_reported_at"),
        arrival_reported_by=item.get("arrival_reported_by"),
        completion_problem=bool(item.get("completion_problem", False)),
        completion_requested_at=item.get("completion_requested_at"),
        completion_requested_by=item.get("completion_requested_by"),
        completion_reason=item.get("completion_reason"),
        completion_near_destination=bool(
            item.get("completion_near_destination", False)
        ),
        completion_confirmed_by=item.get("completion_confirmed_by"),
        cancelled_at=item.get("cancelled_at"),
        cancelled_by=item.get("cancelled_by"),
        cancellation_reason=item.get("cancellation_reason"),
        cancellation_details=item.get("cancellation_details"),
        cancellation_status_code=item.get("cancellation_status_code"),
        cancellation_reason_label=item.get("cancellation_reason_label"),
        cancellation_previous_status=item.get("cancellation_previous_status"),
        cancellation_stage=item.get("cancellation_stage"),
        cancellation_review_required=bool(
            item.get("cancellation_review_required", False)
        ),
        cancellation_admin_status=item.get(
            "cancellation_admin_status",
            "not_required",
        ),
        cancellation_credit_policy=item.get(
            "cancellation_credit_policy",
            "none",
        ),
        cancellation_credit_message=item.get(
            "cancellation_credit_message"
        ),
        credits_reserved=int(item.get("credits_reserved", 0) or 0),
        credits_status=item.get("credits_status", "none"),
        credits_consumed=int(item.get("credits_consumed", 0) or 0),
        sos_active=bool(item.get("sos_active", False)),
        sos_last_actor=item.get("sos_last_actor"),
        sos_last_at=item.get("sos_last_at"),
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


def _distance_meters(
    lat1: float,
    lng1: float,
    lat2: float,
    lng2: float,
) -> float:
    radius = 6_371_000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lng2 - lng1)

    value = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1)
        * math.cos(phi2)
        * math.sin(delta_lambda / 2) ** 2
    )

    return 2 * radius * math.atan2(
        math.sqrt(value),
        math.sqrt(1 - value),
    )


def _active_trip_status(status: str) -> bool:
    return status in {
        "accepted",
        "driver_en_route",
        "driver_arrived",
        "in_progress",
        "arrival_reported",
    }


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
            "ride": _payload(item),
        },
    )

    await _notify_updated(item)


def _other_call_actor(actor: str) -> str:
    return "driver" if actor == "passenger" else "passenger"


def _voice_call_public(call: dict) -> dict:
    return {
        "id": call["id"],
        "caller": call["caller"],
        "callee": call["callee"],
        "status": call["status"],
        "created_at": call["created_at"],
        "updated_at": call["updated_at"],
        "accepted_at": call.get("accepted_at"),
        "ended_at": call.get("ended_at"),
        "ended_by": call.get("ended_by"),
        "signals": list(call.get("signals", [])),
    }


def _current_voice_call(item: dict) -> dict:
    call = item.get("voice_call")

    if not isinstance(call, dict):
        raise HTTPException(
            status_code=404,
            detail="No hay una llamada activa para este viaje.",
        )

    return call


@router.post("/{request_id}/voice-call/start")
async def start_voice_call(
    request_id: str,
    payload: VoiceCallStartRequest,
) -> dict:
    async with _store_lock:
        item = _get_item(request_id)

        if not _active_trip_status(item["status"]):
            raise HTTPException(
                status_code=409,
                detail="La llamada solo está disponible durante un viaje activo.",
            )

        existing = item.get("voice_call")

        if (
            isinstance(existing, dict)
            and existing.get("status")
            in {"ringing", "accepted", "connected"}
        ):
            raise HTTPException(
                status_code=409,
                detail="Ya existe una llamada activa en este viaje.",
            )

        now = _now()
        call = {
            "id": str(uuid4()),
            "caller": payload.actor,
            "callee": _other_call_actor(payload.actor),
            "status": "ringing",
            "created_at": now,
            "updated_at": now,
            "accepted_at": None,
            "ended_at": None,
            "ended_by": None,
            "signals": [],
        }

        item["voice_call"] = call

    public = _voice_call_public(call)

    await realtime.broadcast_request(
        request_id,
        {
            "event": "voice_call_started",
            "request_id": request_id,
            "call": public,
        },
    )

    return public


@router.get("/{request_id}/voice-call/{actor}")
async def get_voice_call(
    request_id: str,
    actor: Literal["passenger", "driver"],
) -> dict:
    async with _store_lock:
        item = _get_item(request_id)
        call = _current_voice_call(item)

        if actor not in {call["caller"], call["callee"]}:
            raise HTTPException(
                status_code=403,
                detail="Actor no autorizado para esta llamada.",
            )

        return _voice_call_public(call)


@router.post("/{request_id}/voice-call/action")
async def voice_call_action(
    request_id: str,
    payload: VoiceCallActionRequest,
) -> dict:
    async with _store_lock:
        item = _get_item(request_id)
        call = _current_voice_call(item)

        if payload.actor not in {call["caller"], call["callee"]}:
            raise HTTPException(
                status_code=403,
                detail="Actor no autorizado para esta llamada.",
            )

        now = _now()

        if payload.action == "accept":
            if payload.actor != call["callee"]:
                raise HTTPException(
                    status_code=409,
                    detail="Solo quien recibe la llamada puede aceptarla.",
                )

            if call["status"] != "ringing":
                raise HTTPException(
                    status_code=409,
                    detail="La llamada ya no está sonando.",
                )

            call["status"] = "accepted"
            call["accepted_at"] = now
            event = "voice_call_accepted"

        elif payload.action == "reject":
            if payload.actor != call["callee"]:
                raise HTTPException(
                    status_code=409,
                    detail="Solo quien recibe la llamada puede rechazarla.",
                )

            if call["status"] not in {"ringing", "accepted"}:
                raise HTTPException(
                    status_code=409,
                    detail="La llamada ya terminó.",
                )

            call["status"] = "rejected"
            call["ended_at"] = now
            call["ended_by"] = payload.actor
            event = "voice_call_ended"

        else:
            if call["status"] in {"ended", "rejected"}:
                return _voice_call_public(call)

            call["status"] = "ended"
            call["ended_at"] = now
            call["ended_by"] = payload.actor
            event = "voice_call_ended"

        call["updated_at"] = now
        public = _voice_call_public(call)

    await realtime.broadcast_request(
        request_id,
        {
            "event": event,
            "request_id": request_id,
            "call": public,
        },
    )

    return public


@router.post("/{request_id}/voice-call/signal", status_code=201)
async def voice_call_signal(
    request_id: str,
    payload: VoiceCallSignalRequest,
) -> dict:
    async with _store_lock:
        item = _get_item(request_id)
        call = _current_voice_call(item)

        if payload.actor not in {call["caller"], call["callee"]}:
            raise HTTPException(
                status_code=403,
                detail="Actor no autorizado para esta llamada.",
            )

        if call["status"] in {"ended", "rejected"}:
            raise HTTPException(
                status_code=409,
                detail="La llamada ya terminó.",
            )

        now = _now()
        signal = {
            "id": str(uuid4()),
            "actor": payload.actor,
            "signal_type": payload.signal_type,
            "payload": payload.payload,
            "created_at": now,
        }

        signals = call.setdefault("signals", [])
        signals.append(signal)

        if len(signals) > 200:
            del signals[:-200]

        if payload.signal_type == "answer":
            call["status"] = "connected"

        call["updated_at"] = now

    await realtime.broadcast_request(
        request_id,
        {
            "event": "voice_call_signal",
            "request_id": request_id,
            "call_id": call["id"],
            "signal": signal,
        },
    )

    return signal


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
        "driver_lat": None,
        "driver_lng": None,
        "driver_location_updated_at": None,
        "passenger_live_lat": payload.pickup_lat,
        "passenger_live_lng": payload.pickup_lng,
        "passenger_location_updated_at": now,
        "accepted_at": None,
        "arrived_at": None,
        "started_at": None,
        "completed_at": None,
        "arrival_reported_at": None,
        "arrival_reported_by": None,
        "completion_problem": False,
        "completion_requested_at": None,
        "completion_requested_by": None,
        "completion_reason": None,
        "completion_near_destination": False,
        "completion_confirmed_by": None,
        "cancelled_at": None,
        "cancelled_by": None,
        "cancellation_reason": None,
        "cancellation_details": None,
        "cancellation_status_code": None,
        "cancellation_reason_label": None,
        "cancellation_previous_status": None,
        "cancellation_stage": None,
        "cancellation_review_required": False,
        "cancellation_admin_status": "not_required",
        "cancellation_credit_policy": "none",
        "cancellation_credit_message": None,
        "credits_reserved": 0,
        "credits_status": "none",
        "credits_consumed": 0,
        "sos_active": False,
        "sos_last_actor": None,
        "sos_last_at": None,
        "messages": [],
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


_PASSENGER_CANCELLATION_REASONS = {
    "driver_delay": "El conductor está demorando demasiado",
    "driver_no_progress": "El conductor no se acerca a mi ubicación",
    "driver_no_response": "El conductor no responde",
    "change_of_plans": "Ya no necesito el viaje",
    "wrong_pickup": "Me equivoqué en el punto de recojo",
    "wrong_destination": "Me equivoqué en el destino",
    "driver_behavior": "Problema con el conductor",
    "safety": "Me siento inseguro/a",
    "emergency": "Emergencia",
    "other": "Otro motivo",
}

_DRIVER_CANCELLATION_REASONS = {
    "passenger_no_show": "El pasajero no aparece",
    "passenger_delay": "El pasajero está demorando demasiado",
    "passenger_no_response": "El pasajero no responde",
    "wrong_pickup": "La ubicación de recojo es incorrecta o confusa",
    "unsafe_pickup": "El punto de recojo no es seguro",
    "passenger_behavior": "Problema con el pasajero",
    "vehicle_problem": "Problema con el vehículo",
    "emergency": "Emergencia",
    "other": "Otro motivo",
}


def _cancellation_reason_label(actor: str, reason: str) -> str:
    reasons = (
        _DRIVER_CANCELLATION_REASONS
        if actor == "driver"
        else _PASSENGER_CANCELLATION_REASONS
    )
    return reasons.get(reason, reasons["other"])


def _cancellation_policy(
    previous_status: str,
    *,
    credits_reserved: int,
) -> dict:
    reserved = max(0, int(credits_reserved or 0))

    allowed = {
        "searching",
        "counter_offer",
        "accepted",
        "driver_en_route",
        "driver_arrived",
        "in_progress",
        "arrival_reported",
    }

    if previous_status not in allowed:
        raise HTTPException(
            status_code=409,
            detail="El viaje no puede cancelarse en este estado.",
        )

    if previous_status in {"searching", "counter_offer"}:
        return {
            "stage": "before_assignment",
            "review_required": True,
            "admin_status": "pending",
            "credits_status": "none",
            "credits_consumed": 0,
            "policy": "admin_review_no_credits",
            "message": (
                "La cancelación quedó registrada para revisión administrativa. "
                "En esta etapa no hay créditos de conductor que liberar o consumir."
            ),
        }

    if previous_status in {
        "accepted",
        "driver_en_route",
        "driver_arrived",
    }:
        return {
            "stage": "before_trip_start",
            "review_required": True,
            "admin_status": "pending",
            "credits_status": "held_review" if reserved > 0 else "review",
            "credits_consumed": 0,
            "policy": "admin_review_hold",
            "message": (
                "La cancelación quedó pendiente de revisión administrativa. "
                "Los créditos reservados del conductor permanecerán retenidos "
                "hasta que el administrador decida LIBERARLOS o CONSUMIRLOS."
                if reserved > 0
                else
                "La cancelación quedó pendiente de revisión administrativa. "
                "No se aplicará ninguna decisión automática sobre créditos."
            ),
        }

    return {
        "stage": "trip_started",
        "review_required": True,
        "admin_status": "pending",
        "credits_status": "held_review" if reserved > 0 else "review",
        "credits_consumed": 0,
        "policy": "admin_review_hold",
        "message": (
            "El viaje ya había iniciado y la cancelación quedó pendiente "
            "de revisión administrativa. Los créditos no se liberarán ni "
            "se consumirán automáticamente."
        ),
    }


@router.post(
    "/{request_id}/cancel",
    response_model=RideRequestResponse,
)
async def cancel_ride_request(
    request_id: str,
    payload: CancelRideRequest | None = None,
) -> RideRequestResponse:
    actor = payload.actor if payload is not None else "passenger"
    reason = (
        payload.reason.strip()
        if payload is not None and payload.reason.strip()
        else "other"
    )
    details = (
        payload.details.strip()
        if payload is not None
        and payload.details is not None
        and payload.details.strip()
        else None
    )

    allowed_reasons = (
        _DRIVER_CANCELLATION_REASONS
        if actor == "driver"
        else _PASSENGER_CANCELLATION_REASONS
    )

    if reason not in allowed_reasons:
        raise HTTPException(
            status_code=422,
            detail="Motivo de cancelación no reconocido.",
        )

    if reason == "other" and not details:
        raise HTTPException(
            status_code=422,
            detail="Escribe brevemente el motivo de la cancelación.",
        )

    async with _store_lock:
        item = _get_item(request_id)
        previous_status = item["status"]

        if previous_status in {"cancelled", "completed"}:
            return _serialize(item)

        allowed_statuses = {
            "searching",
            "counter_offer",
            "accepted",
            "driver_en_route",
            "driver_arrived",
            "in_progress",
            "arrival_reported",
        }

        if previous_status not in allowed_statuses:
            raise HTTPException(
                status_code=409,
                detail="El viaje no puede cancelarse en este estado.",
            )

        policy = _cancellation_policy(
            previous_status,
            credits_reserved=int(item.get("credits_reserved", 0) or 0),
        )

        now = _now()
        item["status"] = "cancelled"
        item["cancelled_at"] = now
        item["cancelled_by"] = actor
        item["cancellation_status_code"] = (
            "CANCELADO_POR_CONDUCTOR"
            if actor == "driver"
            else "CANCELADO_POR_PASAJERO"
        )
        item["cancellation_reason"] = reason
        item["cancellation_reason_label"] = _cancellation_reason_label(
            actor,
            reason,
        )
        item["cancellation_details"] = details
        item["cancellation_previous_status"] = previous_status
        item["cancellation_stage"] = policy["stage"]
        item["cancellation_review_required"] = policy["review_required"]
        item["cancellation_admin_status"] = policy["admin_status"]
        item["cancellation_credit_policy"] = policy["policy"]
        item["cancellation_credit_message"] = policy["message"]

        item["credits_status"] = policy["credits_status"]
        item["credits_consumed"] = policy["credits_consumed"]

        item["completion_requested_at"] = None
        item["completion_requested_by"] = None
        item["completion_reason"] = None
        item["completion_near_destination"] = False
        item["completion_confirmed_by"] = None
        item["updated_at"] = now

        response = _serialize(item)

    await _notify_removed(
        item,
        reason="cancelled",
    )
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
        item["accepted_at"] = _now()
        # V9: en esta etapa el viaje RESERVA créditos, no los consume.
        # El ledger persistente del PANEL reemplazará este valor prototipo.
        item["credits_reserved"] = max(int(item.get("credits_reserved", 0)), 70)
        item["credits_status"] = "reserved"
        item["credits_consumed"] = 0
        item["updated_at"] = item["accepted_at"]

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
        item["accepted_at"] = _now()
        # V9: en esta etapa el viaje RESERVA créditos, no los consume.
        # El ledger persistente del PANEL reemplazará este valor prototipo.
        item["credits_reserved"] = max(int(item.get("credits_reserved", 0)), 70)
        item["credits_status"] = "reserved"
        item["credits_consumed"] = 0
        item["updated_at"] = item["accepted_at"]

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
        item["driver_lat"] = None
        item["driver_lng"] = None
        item["driver_location_updated_at"] = None
        item["accepted_at"] = None
        item["arrived_at"] = None
        item["started_at"] = None
        item["completed_at"] = None
        item["arrival_reported_at"] = None
        item["arrival_reported_by"] = None
        item["completion_problem"] = False
        item["completion_requested_at"] = None
        item["completion_requested_by"] = None
        item["completion_reason"] = None
        item["completion_near_destination"] = False
        item["completion_confirmed_by"] = None
        item["cancelled_at"] = None
        item["cancelled_by"] = None
        item["cancellation_reason"] = None
        item["cancellation_details"] = None
        item["cancellation_status_code"] = None
        item["cancellation_reason_label"] = None
        item["cancellation_previous_status"] = None
        item["cancellation_stage"] = None
        item["cancellation_review_required"] = False
        item["cancellation_admin_status"] = "not_required"
        item["cancellation_credit_policy"] = "none"
        item["cancellation_credit_message"] = None
        item["credits_reserved"] = 0
        item["credits_status"] = "none"
        item["credits_consumed"] = 0
        item["sos_active"] = False
        item["sos_last_actor"] = None
        item["sos_last_at"] = None
        item["messages"] = []
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

@router.post(
    "/{request_id}/passenger-location",
    response_model=RideRequestResponse,
)
async def update_passenger_location(
    request_id: str,
    payload: DriverLocationUpdate,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] not in {
            "accepted",
            "driver_en_route",
            "driver_arrived",
            "in_progress",
            "arrival_reported",
        }:
            raise HTTPException(
                status_code=409,
                detail="El viaje no acepta ubicación del pasajero en este estado.",
            )

        item["passenger_live_lat"] = float(payload.latitude)
        item["passenger_live_lng"] = float(payload.longitude)
        item["passenger_location_updated_at"] = _now()
        item["updated_at"] = item["passenger_location_updated_at"]
        response = _serialize(item)

    await realtime.broadcast_request(
        request_id,
        {
            "event": "passenger_location",
            "request_id": request_id,
            "latitude": response.passenger_live_lat,
            "longitude": response.passenger_live_lng,
            "status": response.status,
            "updated_at": response.passenger_location_updated_at,
        },
    )

    return response


@router.post(
    "/{request_id}/driver-location",
    response_model=RideRequestResponse,
)
async def update_driver_location(
    request_id: str,
    payload: DriverLocationUpdate,
) -> RideRequestResponse:
    status_changed = False

    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] not in {
            "accepted",
            "driver_en_route",
            "driver_arrived",
            "in_progress",
            "arrival_reported",
        }:
            raise HTTPException(
                status_code=409,
                detail="El viaje no acepta ubicación del conductor en este estado.",
            )

        item["driver_lat"] = float(payload.latitude)
        item["driver_lng"] = float(payload.longitude)
        item["driver_location_updated_at"] = _now()

        if item["status"] == "accepted":
            item["status"] = "driver_en_route"
            status_changed = True

        item["updated_at"] = item["driver_location_updated_at"]
        response = _serialize(item)

    await realtime.broadcast_request(
        request_id,
        {
            "event": "driver_location",
            "request_id": request_id,
            "latitude": response.driver_lat,
            "longitude": response.driver_lng,
            "status": response.status,
            "updated_at": response.driver_location_updated_at,
        },
    )

    if status_changed:
        await _notify_updated(item)

    return response


@router.post(
    "/{request_id}/arrived",
    response_model=RideRequestResponse,
)
async def driver_arrived(
    request_id: str,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] not in {
            "accepted",
            "driver_en_route",
        }:
            raise HTTPException(
                status_code=409,
                detail="El viaje no puede marcarse como llegado en este estado.",
            )

        driver_lat = item.get("driver_lat")
        driver_lng = item.get("driver_lng")
        pickup_lat = item.get("pickup_lat")
        pickup_lng = item.get("pickup_lng")

        if (
            driver_lat is None
            or driver_lng is None
            or pickup_lat is None
            or pickup_lng is None
        ):
            raise HTTPException(
                status_code=409,
                detail=(
                    "MIGO todavía no puede verificar tu llegada. "
                    "Espera a que el GPS del conductor esté disponible."
                ),
            )

        pickup_distance = _distance_meters(
            float(driver_lat),
            float(driver_lng),
            float(pickup_lat),
            float(pickup_lng),
        )

        if pickup_distance > 250:
            raise HTTPException(
                status_code=409,
                detail=(
                    "Todavía estás lejos del punto de recogida "
                    f"({round(pickup_distance)} m)."
                ),
            )

        item["status"] = "driver_arrived"
        item["arrived_at"] = _now()
        item["updated_at"] = item["arrived_at"]
        response = _serialize(item)

    await _notify_updated(item)
    return response


@router.post(
    "/{request_id}/start",
    response_model=RideRequestResponse,
)
async def start_ride(
    request_id: str,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "driver_arrived":
            raise HTTPException(
                status_code=409,
                detail="Primero el conductor debe marcar que llegó.",
            )

        item["status"] = "in_progress"
        item["started_at"] = _now()
        item["updated_at"] = item["started_at"]
        response = _serialize(item)

    await _notify_updated(item)
    return response



@router.post(
    "/{request_id}/complete-request",
    response_model=RideRequestResponse,
)
async def request_completion(
    request_id: str,
    payload: CompletionRequest | None = None,
) -> RideRequestResponse:
    actor = payload.actor if payload is not None else "driver"
    reason = (
        payload.reason.strip()
        if payload is not None
        and payload.reason is not None
        and payload.reason.strip()
        else "mutual_finish"
    )

    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "in_progress":
            raise HTTPException(
                status_code=409,
                detail="Solo un viaje en curso puede solicitar finalización.",
            )

        near_destination = False
        driver_lat = item.get("driver_lat")
        driver_lng = item.get("driver_lng")
        destination_lat = item.get("destination_lat")
        destination_lng = item.get("destination_lng")

        if (
            driver_lat is not None
            and driver_lng is not None
            and destination_lat is not None
            and destination_lng is not None
        ):
            meters = _distance_meters(
                float(driver_lat),
                float(driver_lng),
                float(destination_lat),
                float(destination_lng),
            )
            near_destination = meters <= 400

        now = _now()
        item["status"] = "arrival_reported"
        item["arrival_reported_at"] = now
        item["arrival_reported_by"] = actor
        item["completion_requested_at"] = now
        item["completion_requested_by"] = actor
        item["completion_reason"] = reason
        item["completion_near_destination"] = near_destination
        item["completion_confirmed_by"] = None
        item["completion_problem"] = False
        item["updated_at"] = now

        response = _serialize(item)

    await _notify_updated(item)
    return response

@router.post(
    "/{request_id}/complete",
    response_model=RideRequestResponse,
)
async def complete_ride_legacy(
    request_id: str,
) -> RideRequestResponse:
    """Compatibilidad temporal con clientes anteriores.

    La UI V6 usa complete-request + complete-confirm.
    """
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "in_progress":
            raise HTTPException(
                status_code=409,
                detail="Solo un viaje en curso puede finalizarse.",
            )

        item["status"] = "completed"
        item["completed_at"] = _now()
        item["completion_confirmed_by"] = "legacy"
        item["credits_status"] = "consumed"
        item["credits_consumed"] = int(item.get("credits_reserved", 0) or 0)
        item["updated_at"] = item["completed_at"]
        response = _serialize(item)

    await _notify_updated(item)
    return response


@router.post(
    "/{request_id}/complete-confirm",
    response_model=RideRequestResponse,
)
async def confirm_completion(
    request_id: str,
    payload: CompletionRequest | None = None,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "arrival_reported":
            raise HTTPException(
                status_code=409,
                detail="El viaje todavía no tiene una finalización pendiente.",
            )

        requested_by = item.get("completion_requested_by")
        actor = (
            payload.actor
            if payload is not None
            else ("passenger" if requested_by == "driver" else "driver")
        )

        if requested_by == actor:
            raise HTTPException(
                status_code=409,
                detail="La otra parte debe confirmar la finalización.",
            )

        item["status"] = "completed"
        item["completed_at"] = _now()
        item["completion_confirmed_by"] = actor
        item["credits_status"] = "consumed"
        item["credits_consumed"] = int(item.get("credits_reserved", 0) or 0)
        item["updated_at"] = item["completed_at"]
        response = _serialize(item)

    await _notify_updated(item)
    return response

@router.post(
    "/{request_id}/complete-problem",
    response_model=RideRequestResponse,
)
async def report_completion_problem(
    request_id: str,
) -> RideRequestResponse:
    async with _store_lock:
        item = _get_item(request_id)

        if item["status"] != "arrival_reported":
            raise HTTPException(
                status_code=409,
                detail="No existe una finalización pendiente.",
            )

        item["status"] = "in_progress"
        item["completion_problem"] = True
        item["completion_requested_at"] = None
        item["completion_requested_by"] = None
        item["completion_reason"] = None
        item["completion_near_destination"] = False
        item["completion_confirmed_by"] = None
        item["arrival_reported_at"] = None
        item["arrival_reported_by"] = None
        item["updated_at"] = _now()
        response = _serialize(item)

    await _notify_updated(item)
    return response

@router.get(
    "/{request_id}/messages",
)
async def list_messages(
    request_id: str,
) -> list[dict]:
    async with _store_lock:
        item = _get_item(request_id)
        return list(item.get("messages", []))


@router.post(
    "/{request_id}/messages",
    status_code=201,
)
async def send_message(
    request_id: str,
    payload: RideMessageRequest,
) -> dict:
    async with _store_lock:
        item = _get_item(request_id)

        if not _active_trip_status(item["status"]):
            raise HTTPException(
                status_code=409,
                detail="El chat solo está disponible durante un viaje activo.",
            )

        text = payload.text.strip()
        kind = payload.kind
        media = payload.media_base64

        if kind == "text" and not text:
            raise HTTPException(
                status_code=422,
                detail="El mensaje de texto está vacío.",
            )

        if kind in {"image", "audio"}:
            if media is None or not media.strip():
                raise HTTPException(
                    status_code=422,
                    detail="El mensaje multimedia no contiene archivo.",
                )

            if len(media) > 2_500_000:
                raise HTTPException(
                    status_code=413,
                    detail="El archivo multimedia es demasiado grande.",
                )

        message = {
            "id": str(uuid4()),
            "actor": payload.actor,
            "kind": kind,
            "text": text,
            "media_base64": media,
            "media_mime": payload.media_mime,
            "duration_ms": payload.duration_ms,
            "created_at": _now(),
        }

        messages = item.setdefault("messages", [])
        messages.append(message)
        item["updated_at"] = message["created_at"]

    await realtime.broadcast_request(
        request_id,
        {
            "event": "ride_message",
            "request_id": request_id,
            "message": message,
        },
    )

    return message


@router.post(
    "/{request_id}/sos",
)
async def trigger_sos(
    request_id: str,
    payload: SafetyAlertRequest,
) -> dict:
    async with _store_lock:
        item = _get_item(request_id)

        if not _active_trip_status(item["status"]):
            raise HTTPException(
                status_code=409,
                detail="El botón SOS solo está disponible durante un viaje activo.",
            )

        now = _now()
        item["sos_active"] = True
        item["sos_last_actor"] = payload.actor
        item["sos_last_at"] = now
        item["updated_at"] = now

        event = {
            "event": "sos_alert",
            "request_id": request_id,
            "actor": payload.actor,
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "created_at": now,
        }

    await realtime.broadcast_request(
        request_id,
        event,
    )

    return {
        "ok": True,
        **event,
    }
