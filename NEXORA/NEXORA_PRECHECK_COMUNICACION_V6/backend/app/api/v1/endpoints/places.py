from __future__ import annotations

import base64
import json
from pathlib import Path
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/places", tags=["places"])

_GOOGLE_AUTOCOMPLETE = "https://places.googleapis.com/v1/places:autocomplete"
_GOOGLE_DETAILS = "https://places.googleapis.com/v1/places/{place_id}"
_PHOTON_SEARCH = "https://photon.komoot.io/api/"


def _read_google_key() -> str | None:
    env_path = Path(__file__).resolve().parents[4] / ".env"
    if not env_path.exists():
        return None

    for raw in env_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if line.startswith("GOOGLE_PLACES_API_KEY="):
            value = line.split("=", 1)[1].strip()
            if value.startswith("AIza"):
                return value

    return None


def _encode_photon_place(label: str, lat: float, lng: float) -> str:
    payload = json.dumps(
        {
            "label": label,
            "latitude": lat,
            "longitude": lng,
        },
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")

    token = base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")
    return f"photon:{token}"


def _decode_photon_place(place_id: str) -> dict[str, Any]:
    token = place_id.removeprefix("photon:")
    token += "=" * (-len(token) % 4)

    try:
        raw = base64.urlsafe_b64decode(token.encode("ascii"))
        data = json.loads(raw.decode("utf-8"))
        return {
            "label": str(data["label"]),
            "latitude": float(data["latitude"]),
            "longitude": float(data["longitude"]),
        }
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail="Identificador Photon inválido.",
        ) from exc


def _photon_label(properties: dict[str, Any]) -> str:
    candidates = [
        properties.get("name"),
        properties.get("housenumber"),
        properties.get("street"),
        properties.get("district"),
        properties.get("locality"),
        properties.get("city"),
        properties.get("county"),
        properties.get("state"),
        properties.get("postcode"),
        properties.get("country"),
    ]

    parts: list[str] = []
    for value in candidates:
        if value is None:
            continue
        text = str(value).strip()
        if text and text not in parts:
            parts.append(text)

    return ", ".join(parts) or "Ubicación"


async def _google_autocomplete(
    input_text: str,
    lat: float | None,
    lng: float | None,
) -> list[dict[str, Any]] | None:
    key = _read_google_key()
    if not key:
        return None

    body: dict[str, Any] = {
        "input": input_text,
        "languageCode": "es",
        "regionCode": "PE",
    }

    if lat is not None and lng is not None:
        body["locationBias"] = {
            "circle": {
                "center": {
                    "latitude": lat,
                    "longitude": lng,
                },
                "radius": 50000.0,
            }
        }

    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": (
            "suggestions.placePrediction.placeId,"
            "suggestions.placePrediction.text.text"
        ),
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.post(
                _GOOGLE_AUTOCOMPLETE,
                json=body,
                headers=headers,
            )
    except httpx.HTTPError:
        return None

    if response.status_code != 200:
        return None

    data = response.json()
    results: list[dict[str, Any]] = []

    for suggestion in data.get("suggestions", []):
        prediction = suggestion.get("placePrediction") or {}
        place_id = prediction.get("placeId")
        text = (prediction.get("text") or {}).get("text")

        if place_id and text:
            results.append(
                {
                    "place_id": str(place_id),
                    "text": str(text),
                    "provider": "google",
                }
            )

    return results


async def _photon_autocomplete(
    input_text: str,
    lat: float | None,
    lng: float | None,
) -> list[dict[str, Any]]:
    params: dict[str, str] = {
        "q": input_text,
        "limit": "6",
    }

    if lat is not None and lng is not None:
        params["lat"] = str(lat)
        params["lon"] = str(lng)
        params["zoom"] = "13"

    headers = {
        "User-Agent": "MIGO-Drive-Development/1.0",
        "Accept": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.get(
                _PHOTON_SEARCH,
                params=params,
                headers=headers,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Proveedor de búsqueda temporal no disponible: {exc}",
        ) from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Photon HTTP {response.status_code}",
        )

    data = response.json()
    results: list[dict[str, Any]] = []

    for feature in data.get("features", []):
        geometry = feature.get("geometry") or {}
        coordinates = geometry.get("coordinates") or []
        properties = feature.get("properties") or {}

        if len(coordinates) < 2:
            continue

        try:
            lng_value = float(coordinates[0])
            lat_value = float(coordinates[1])
        except (TypeError, ValueError):
            continue

        label = _photon_label(properties)

        results.append(
            {
                "place_id": _encode_photon_place(
                    label,
                    lat_value,
                    lng_value,
                ),
                "text": label,
                "provider": "photon",
            }
        )

    return results


@router.get("/autocomplete")
async def autocomplete(
    input: str = Query(min_length=2, max_length=160),
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
) -> list[dict[str, Any]]:
    query = input.strip()

    google = await _google_autocomplete(query, lat, lng)

    if google:
        return google

    # Fallback temporal de desarrollo.
    return await _photon_autocomplete(query, lat, lng)


async def _google_details(place_id: str) -> dict[str, Any]:
    key = _read_google_key()
    if not key:
        raise HTTPException(
            status_code=503,
            detail="Google Places no está disponible.",
        )

    headers = {
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": (
            "id,displayName,formattedAddress,location"
        ),
    }

    url = _GOOGLE_DETAILS.format(
        place_id=httpx.URL(place_id).raw_path.decode("utf-8")
    )

    async with httpx.AsyncClient(timeout=8.0) as client:
        response = await client.get(url, headers=headers)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Google Place Details HTTP {response.status_code}",
        )

    data = response.json()
    location = data.get("location") or {}

    label = (
        data.get("formattedAddress")
        or (data.get("displayName") or {}).get("text")
        or "Destino"
    )

    try:
        latitude = float(location["latitude"])
        longitude = float(location["longitude"])
    except (KeyError, TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail="Google no devolvió coordenadas del lugar.",
        ) from exc

    return {
        "label": str(label),
        "latitude": latitude,
        "longitude": longitude,
        "provider": "google",
    }


@router.get("/{place_id:path}")
async def place_details(place_id: str) -> dict[str, Any]:
    if place_id.startswith("photon:"):
        result = _decode_photon_place(place_id)
        result["provider"] = "photon"
        return result

    return await _google_details(place_id)
