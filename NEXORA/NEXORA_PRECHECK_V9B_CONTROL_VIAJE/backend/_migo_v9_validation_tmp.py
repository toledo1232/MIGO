
from fastapi.testclient import TestClient

from app.main import app


def ride_payload():
    return {
        "offer": 20.0,
        "pickup_text": "Plaza de Armas de Huaraz",
        "destination_text": "Monterrey, Independencia, Huaraz",
        "payment_method": "Yape",
        "pickup_lat": -9.52779,
        "pickup_lng": -77.52778,
        "destination_lat": -9.47155,
        "destination_lng": -77.53771,
        "passenger_name": "Pasajero MIGO",
        "passenger_rating": 4.9,
        "passenger_trips": 20,
    }


def driver_payload():
    return {
        "driver_name": "Conductor MIGO",
        "driver_photo_base64": "bWlnby1kcml2ZXItcGhvdG8tMTIzNDU2Nzg5MA==",
        "driver_rating": 4.9,
        "driver_trips": 100,
        "vehicle_model": "Toyota Yaris",
        "vehicle_plate": "ABC-123",
        "vehicle_color": "Plata",
    }


def create_and_accept(client):
    created = client.post("/api/v1/ride-requests", json=ride_payload())
    assert created.status_code == 201, created.text
    ride_id = created.json()["id"]

    accepted = client.post(
        f"/api/v1/ride-requests/{ride_id}/accept",
        json=driver_payload(),
    )
    assert accepted.status_code == 200, accepted.text
    return ride_id, accepted.json()


def test_accept_reserves_credits_and_prestart_cancel_releases():
    client = TestClient(app)
    ride_id, accepted = create_and_accept(client)

    assert accepted["credits_status"] == "reserved"
    assert accepted["credits_reserved"] >= 70
    assert accepted["credits_consumed"] == 0

    cancelled = client.post(
        f"/api/v1/ride-requests/{ride_id}/cancel",
        json={
            "actor": "passenger",
            "reason": "driver_delay",
            "details": "El conductor está demorando.",
        },
    )
    assert cancelled.status_code == 200, cancelled.text

    data = cancelled.json()
    assert data["status"] == "cancelled"
    assert data["cancelled_by"] == "passenger"
    assert data["cancellation_reason"] == "driver_delay"
    assert data["credits_status"] == "released"
    assert data["credits_consumed"] == 0
    assert data["cancellation_review_required"] is False


def test_in_progress_cancel_goes_to_review_without_consuming_blindly():
    client = TestClient(app)
    ride_id, _ = create_and_accept(client)

    client.post(
        f"/api/v1/ride-requests/{ride_id}/driver-location",
        json={"latitude": -9.52780, "longitude": -77.52779},
    )
    arrived = client.post(
        f"/api/v1/ride-requests/{ride_id}/arrived"
    )
    assert arrived.status_code == 200, arrived.text

    started = client.post(
        f"/api/v1/ride-requests/{ride_id}/start"
    )
    assert started.status_code == 200, started.text

    cancelled = client.post(
        f"/api/v1/ride-requests/{ride_id}/cancel",
        json={
            "actor": "driver",
            "reason": "passenger_behavior",
            "details": "Se requiere revisión.",
        },
    )
    assert cancelled.status_code == 200, cancelled.text

    data = cancelled.json()
    assert data["status"] == "cancelled"
    assert data["credits_status"] == "review"
    assert data["credits_consumed"] == 0
    assert data["cancellation_review_required"] is True


def test_early_finish_requires_mutual_confirmation_then_consumes():
    client = TestClient(app)
    ride_id, _ = create_and_accept(client)

    client.post(
        f"/api/v1/ride-requests/{ride_id}/driver-location",
        json={"latitude": -9.52780, "longitude": -77.52779},
    )
    client.post(f"/api/v1/ride-requests/{ride_id}/arrived")
    client.post(f"/api/v1/ride-requests/{ride_id}/start")

    requested = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-request",
        json={
            "actor": "passenger",
            "reason": "mutual_early_finish",
        },
    )
    assert requested.status_code == 200, requested.text

    request_data = requested.json()
    assert request_data["status"] == "arrival_reported"
    assert request_data["completion_requested_by"] == "passenger"
    assert request_data["credits_status"] == "reserved"

    same_actor = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-confirm",
        json={"actor": "passenger"},
    )
    assert same_actor.status_code == 409

    confirmed = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-confirm",
        json={"actor": "driver"},
    )
    assert confirmed.status_code == 200, confirmed.text

    data = confirmed.json()
    assert data["status"] == "completed"
    assert data["completion_confirmed_by"] == "driver"
    assert data["credits_status"] == "consumed"
    assert data["credits_consumed"] == data["credits_reserved"]


def test_reject_finish_request_returns_trip_to_in_progress():
    client = TestClient(app)
    ride_id, _ = create_and_accept(client)

    client.post(
        f"/api/v1/ride-requests/{ride_id}/driver-location",
        json={"latitude": -9.52780, "longitude": -77.52779},
    )
    client.post(f"/api/v1/ride-requests/{ride_id}/arrived")
    client.post(f"/api/v1/ride-requests/{ride_id}/start")

    requested = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-request",
        json={
            "actor": "driver",
            "reason": "mutual_early_finish",
        },
    )
    assert requested.status_code == 200

    resumed = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-problem",
    )
    assert resumed.status_code == 200, resumed.text
    assert resumed.json()["status"] == "in_progress"
