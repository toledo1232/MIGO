from pydantic import ValidationError

from app.api.v1.endpoints.ride_requests import RideMessageRequest


def test_text_message():
    item = RideMessageRequest(actor="passenger", text="Hola")
    assert item.kind == "text"


def test_image_message():
    item = RideMessageRequest(
        actor="driver",
        kind="image",
        text="Foto",
        media_base64="YWJj",
        media_mime="image/jpeg",
    )
    assert item.kind == "image"


def test_audio_message():
    item = RideMessageRequest(
        actor="passenger",
        kind="audio",
        text="Nota de voz",
        media_base64="YWJj",
        media_mime="audio/mp4",
        duration_ms=2500,
    )
    assert item.duration_ms == 2500


def test_audio_duration_limit():
    try:
        RideMessageRequest(
            actor="passenger",
            kind="audio",
            media_base64="YWJj",
            duration_ms=61000,
        )
    except ValidationError:
        return

    raise AssertionError("duration_ms > 60000 debió fallar")
