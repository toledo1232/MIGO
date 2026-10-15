from __future__ import annotations

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/routes", tags=["routes"])

_OSRM_BASE_URL = "https://router.project-osrm.org"
_OSRM_USER_AGENT = "MIGO-Drive-Development/1.0"


class RoutePoint(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class RouteRequest(BaseModel):
    origin: RoutePoint
    destination: RoutePoint


@router.post("/compute")
async def compute_route(
    payload: RouteRequest,
) -> dict[str, object]:
    origin = payload.origin
    destination = payload.destination

    coordinates = (
        f"{origin.longitude:.7f},{origin.latitude:.7f};"
        f"{destination.longitude:.7f},{destination.latitude:.7f}"
    )

    url = f"{_OSRM_BASE_URL}/route/v1/driving/{coordinates}"

    params = {
        "alternatives": "false",
        "steps": "false",
        "overview": "full",
        "geometries": "polyline",
    }

    headers = {
        "User-Agent": _OSRM_USER_AGENT,
        "Accept": "application/json",
    }

    try:
        async with httpx.AsyncClient(
            timeout=12.0,
            follow_redirects=True,
        ) as client:
            response = await client.get(
                url,
                params=params,
                headers=headers,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                "No se pudo conectar con el motor de rutas "
                f"de desarrollo: {exc}"
            ),
        ) from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=(
                f"Motor de rutas HTTP {response.status_code}: "
                f"{response.text[:700]}"
            ),
        )

    try:
        data = response.json()
    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail="El motor de rutas devolvió JSON inválido.",
        ) from exc

    if data.get("code") != "Ok":
        raise HTTPException(
            status_code=404,
            detail=(
                "No se encontró una ruta vial. "
                f"OSRM: {data.get('code')} "
                f"{data.get('message', '')}"
            ),
        )

    routes = data.get("routes") or []

    if not routes:
        raise HTTPException(
            status_code=404,
            detail="El motor no devolvió ninguna ruta vial.",
        )

    route = routes[0]

    try:
        distance_meters = float(route.get("distance") or 0)
        duration_seconds = float(route.get("duration") or 0)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail="Distancia o duración de ruta inválida.",
        ) from exc

    encoded_polyline = route.get("geometry")

    if not isinstance(encoded_polyline, str) or not encoded_polyline:
        raise HTTPException(
            status_code=502,
            detail="El motor no devolvió la polilínea vial.",
        )

    return {
        "provider": "osrm",
        "development_only": True,
        "distance_meters": round(distance_meters),
        "distance_km": round(distance_meters / 1000, 2),
        "duration_seconds": round(duration_seconds),
        "duration_minutes": (
            0
            if duration_seconds <= 0
            else max(1, round(duration_seconds / 60))
        ),
        "encoded_polyline": encoded_polyline,
    }
