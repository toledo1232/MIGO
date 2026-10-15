from pydantic import ValidationError

from app.api.v1.endpoints.ride_requests import (
    VoiceCallActionRequest,
    VoiceCallSignalRequest,
    VoiceCallStartRequest,
)


def test_voice_call_start_actor():
    item = VoiceCallStartRequest(actor="passenger")
    assert item.actor == "passenger"


def test_voice_call_action():
    item = VoiceCallActionRequest(
        actor="driver",
        action="accept",
    )
    assert item.action == "accept"


def test_voice_signal_offer():
    item = VoiceCallSignalRequest(
        actor="passenger",
        signal_type="offer",
        payload={
            "sdp": "v=0",
            "type": "offer",
        },
    )
    assert item.signal_type == "offer"


def test_invalid_voice_action():
    try:
        VoiceCallActionRequest(
            actor="passenger",
            action="pay",
        )
    except ValidationError:
        return

    raise AssertionError("La acción inválida debió ser rechazada.")
