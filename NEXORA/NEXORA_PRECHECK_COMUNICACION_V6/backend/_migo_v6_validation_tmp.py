
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
    return ride_id


def test_v6_route_independent_flow():
    client = TestClient(app)
    ride_id = create_and_accept(client)

    passenger_location = client.post(
        f"/api/v1/ride-requests/{ride_id}/passenger-location",
        json={"latitude": -9.52779, "longitude": -77.52778},
    )
    assert passenger_location.status_code == 200

    far_driver = client.post(
        f"/api/v1/ride-requests/{ride_id}/driver-location",
        json={"latitude": -9.54000, "longitude": -77.54000},
    )
    assert far_driver.status_code == 200
    assert far_driver.json()["status"] == "driver_en_route"

    arrived_far = client.post(
        f"/api/v1/ride-requests/{ride_id}/arrived"
    )
    assert arrived_far.status_code == 409

    near_pickup = client.post(
        f"/api/v1/ride-requests/{ride_id}/driver-location",
        json={"latitude": -9.52780, "longitude": -77.52779},
    )
    assert near_pickup.status_code == 200

    arrived = client.post(
        f"/api/v1/ride-requests/{ride_id}/arrived"
    )
    assert arrived.status_code == 200, arrived.text
    assert arrived.json()["status"] == "driver_arrived"

    message = client.post(
        f"/api/v1/ride-requests/{ride_id}/messages",
        json={"actor": "driver", "text": "Ya estoy en el punto de recojo."},
    )
    assert message.status_code == 201, message.text

    listed = client.get(
        f"/api/v1/ride-requests/{ride_id}/messages"
    )
    assert listed.status_code == 200
    assert listed.json()[-1]["text"] == "Ya estoy en el punto de recojo."

    sos = client.post(
        f"/api/v1/ride-requests/{ride_id}/sos",
        json={
            "actor": "passenger",
            "latitude": -9.52779,
            "longitude": -77.52778,
        },
    )
    assert sos.status_code == 200, sos.text

    started = client.post(
        f"/api/v1/ride-requests/{ride_id}/start"
    )
    assert started.status_code == 200, started.text
    assert started.json()["status"] == "in_progress"

    finish_far = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-request",
        json={"actor": "driver"},
    )
    assert finish_far.status_code == 409

    destination_location = client.post(
        f"/api/v1/ride-requests/{ride_id}/driver-location",
        json={"latitude": -9.47156, "longitude": -77.53770},
    )
    assert destination_location.status_code == 200

    finish = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-request",
        json={"actor": "driver"},
    )
    assert finish.status_code == 200, finish.text
    assert finish.json()["status"] == "arrival_reported"

    confirm = client.post(
        f"/api/v1/ride-requests/{ride_id}/complete-confirm"
    )
    assert confirm.status_code == 200, confirm.text
    assert confirm.json()["status"] == "completed"


def test_driver_photo_required():
    client = TestClient(app)
    created = client.post("/api/v1/ride-requests", json=ride_payload())
    ride_id = created.json()["id"]

    invalid = driver_payload()
    invalid["driver_photo_base64"] = ""

    response = client.post(
        f"/api/v1/ride-requests/{ride_id}/accept",
        json=invalid,
    )
    assert response.status_code == 422


def test_legacy_complete_still_works():
    client = TestClient(app)
    ride_id = create_and_accept(client)

    client.post(
        f"/api/v1/ride-requests/{ride_id}/driver-location",
        json={"latitude": -9.52780, "longitude": -77.52779},
    )
    arrived = client.post(f"/api/v1/ride-requests/{ride_id}/arrived")
    assert arrived.status_code == 200

    started = client.post(f"/api/v1/ride-requests/{ride_id}/start")
    assert started.status_code == 200

    completed = client.post(f"/api/v1/ride-requests/{ride_id}/complete")
    assert completed.status_code == 200
    assert completed.json()["status"] == "completed"
