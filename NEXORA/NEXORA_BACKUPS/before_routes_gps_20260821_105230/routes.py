from __future__ import annotations

from pathlib import Path

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/routes", tags=["routes"])

_GOOGLE_ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
_FIELD_MASK = "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline"


class RoutePoint(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class RouteRequest(BaseModel):
    origin: RoutePoint
    destination: RoutePoint


def _read_google_backend_key() -> str:
    env_path = Path(__file__).resolve().parents[4] / ".env"

    if not env_path.exists():
        raise HTTPException(status_code=500, detail="No existe backend/.env")

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("GOOGLE_PLACES_API_KEY="):
            key = line.split("=", 1)[1].strip()
            if key:
                return key

    raise HTTPException(
        status_code=500,
        detail="GOOGLE_PLACES_API_KEY no está configurada.",
    )


def _duration_seconds(value: str) -> float:
    if not value.endswith("s"):
        return 0.0

    try:
        return float(value[:-1])
    except ValueError:
        return 0.0


@router.post("/compute")
async def compute_route(payload: RouteRequest) -> dict[str, object]:
    key = _read_google_backend_key()

    body = {
        "origin": {
            "location": {
                "latLng": {
                    "latitude": payload.origin.latitude,
                    "longitude": payload.origin.longitude,
                }
            }
        },
        "destination": {
            "location": {
                "latLng": {
                    "latitude": payload.destination.latitude,
                    "longitude": payload.destination.longitude,
                }
            }
        },
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
        "computeAlternativeRoutes": False,
        "languageCode": "es-PE",
        "units": "METRIC",
    }

    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": _FIELD_MASK,
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                _GOOGLE_ROUTES_URL,
                json=body,
                headers=headers,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"No se pudo conectar con Google Routes: {exc}",
        ) from exc

    if response.status_code != 200:
        detail = response.text[:1200]
        raise HTTPException(
            status_code=502,
            detail=f"Google Routes HTTP {response.status_code}: {detail}",
        )

    data = response.json()
    routes = data.get("routes") or []

    if not routes:
        raise HTTPException(
            status_code=404,
            detail="Google Routes no encontró una ruta.",
        )

    route = routes[0]
    distance_meters = int(route.get("distanceMeters") or 0)
    duration_seconds = _duration_seconds(str(route.get("duration") or "0s"))
    encoded_polyline = (
        route.get("polyline", {}).get("encodedPolyline")
        if isinstance(route.get("polyline"), dict)
        else None
    )

    if not encoded_polyline:
        raise HTTPException(
            status_code=502,
            detail="Google Routes no devolvió una polilínea.",
        )

    return {
        "distance_meters": distance_meters,
        "distance_km": round(distance_meters / 1000, 2),
        "duration_seconds": round(duration_seconds),
        "duration_minutes": max(1, round(duration_seconds / 60)),
        "encoded_polyline": encoded_polyline,
    }
