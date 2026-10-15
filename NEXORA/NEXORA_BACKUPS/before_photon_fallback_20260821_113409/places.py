
from typing import Annotated

import httpx
from fastapi import APIRouter, HTTPException, Query, status

from app.core.config import settings


router = APIRouter(
    prefix="/places",
    tags=["places"],
)


def _require_google_key() -> str:
    key = settings.google_places_api_key.strip()

    if not key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Google Places no está configurado. "
                "Agrega GOOGLE_PLACES_API_KEY en backend/.env."
            ),
        )

    return key


@router.get("/autocomplete")
async def autocomplete(
    input: Annotated[str, Query(min_length=2, max_length=120)],
    lat: float | None = None,
    lng: float | None = None,
) -> list[dict[str, str]]:
    key = _require_google_key()

    body: dict[str, object] = {
        "input": input,
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

    async with httpx.AsyncClient(timeout=8.0) as client:
        response = await client.post(
            "https://places.googleapis.com/v1/places:autocomplete",
            json=body,
            headers=headers,
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Google Places no respondió correctamente.",
        )

    raw = response.json()
    result: list[dict[str, str]] = []

    for suggestion in raw.get("suggestions", []):
        prediction = suggestion.get("placePrediction")

        if not prediction:
            continue

        place_id = prediction.get("placeId")
        text = prediction.get("text", {}).get("text")

        if place_id and text:
            result.append(
                {
                    "place_id": place_id,
                    "text": text,
                }
            )

    return result


@router.get("/{place_id}")
async def place_details(
    place_id: str,
) -> dict[str, object]:
    key = _require_google_key()

    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": (
            "id,displayName,formattedAddress,location"
        ),
    }

    async with httpx.AsyncClient(timeout=8.0) as client:
        response = await client.get(
            f"https://places.googleapis.com/v1/places/{place_id}",
            headers=headers,
            params={
                "languageCode": "es",
                "regionCode": "PE",
            },
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="No se pudieron obtener los detalles del lugar.",
        )

    raw = response.json()
    location = raw.get("location") or {}

    latitude = location.get("latitude")
    longitude = location.get("longitude")

    if latitude is None or longitude is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Google Places no devolvió coordenadas.",
        )

    label = (
        raw.get("formattedAddress")
        or (raw.get("displayName") or {}).get("text")
        or "Destino seleccionado"
    )

    return {
        "place_id": raw.get("id", place_id),
        "label": label,
        "latitude": latitude,
        "longitude": longitude,
    }
