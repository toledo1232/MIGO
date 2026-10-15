from __future__ import annotations

import base64
import json
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/places", tags=["places"])

_PHOTON_SEARCH = "https://photon.komoot.io/api/"


def _encode_place(label: str, latitude: float, longitude: float) -> str:
    payload = json.dumps(
        {
            "label": label,
            "latitude": latitude,
            "longitude": longitude,
        },
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")

    token = base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")
    return f"photon:{token}"


def _decode_place(place_id: str) -> dict[str, Any]:
    if not place_id.startswith("photon:"):
        raise HTTPException(
            status_code=400,
            detail="Identificador de lugar no reconocido.",
        )

    token = place_id.removeprefix("photon:")
    token += "=" * (-len(token) % 4)

    try:
        raw = base64.urlsafe_b64decode(token.encode("ascii"))
        data = json.loads(raw.decode("utf-8"))
        return {
            "label": str(data["label"]),
            "latitude": float(data["latitude"]),
            "longitude": float(data["longitude"]),
            "provider": "photon",
        }
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail="Identificador de lugar inválido.",
        ) from exc


def _label(properties: dict[str, Any]) -> str:
    ordered = [
        properties.get("name"),
        properties.get("street"),
        properties.get("housenumber"),
        properties.get("locality"),
        properties.get("district"),
        properties.get("city"),
        properties.get("county"),
        properties.get("state"),
        properties.get("postcode"),
        properties.get("country"),
    ]

    parts: list[str] = []

    for value in ordered:
        if value is None:
            continue
        text = str(value).strip()
        if text and text not in parts:
            parts.append(text)

    return ", ".join(parts) or "Ubicación"


@router.get("/autocomplete")
async def autocomplete(
    input: str = Query(min_length=2, max_length=160),
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
) -> list[dict[str, Any]]:
    params: dict[str, str] = {
        "q": input.strip(),
        "limit": "8",
        "countrycode": "PE",
    }

    if lat is not None and lng is not None:
        params["lat"] = str(lat)
        params["lon"] = str(lng)

    headers = {
        "User-Agent": "MIGO-Drive-Development/1.0",
        "Accept": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                _PHOTON_SEARCH,
                params=params,
                headers=headers,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail="El buscador temporal no está disponible.",
        ) from exc

    if response.status_code != 200:
        detail = response.text[:400]
        raise HTTPException(
            status_code=502,
            detail=(
                f"Photon respondió HTTP {response.status_code}: {detail}"
            ),
        )

    payload = response.json()
    results: list[dict[str, Any]] = []

    for feature in payload.get("features", []):
        geometry = feature.get("geometry") or {}
        coordinates = geometry.get("coordinates") or []
        properties = feature.get("properties") or {}

        if len(coordinates) < 2:
            continue

        try:
            longitude = float(coordinates[0])
            latitude = float(coordinates[1])
        except (TypeError, ValueError):
            continue

        label = _label(properties)

        results.append(
            {
                "place_id": _encode_place(label, latitude, longitude),
                "text": label,
                "provider": "photon",
            }
        )

    return results


@router.get("/{place_id:path}")
async def place_details(place_id: str) -> dict[str, Any]:
    return _decode_place(place_id)
