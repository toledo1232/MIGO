
import base64


def _ride_payload():
    return {
        "offer": 20.0,
        "pickup_text": "Plaza de Armas de Huaraz",
        "destination_text": "Monterrey, Independencia, Huaraz",
        "payment_method": "Yape",
        "pickup_lat": -9.52779,
        "pickup_lng": -77.52778,
        "destination_lat": -9.47155,
        "destination_lng": -77.53771,
        "passenger_name": "Pasajero Prueba",
        "passenger_photo_base64": None,
        "passenger_rating": 4.9,
        "passenger_trips": 12,
    }


def _driver_profile():
    photo = base64.b64encode(
        b"migo-driver-photo-live-trip"
    ).decode("ascii")

    return {
        "driver_name": "Conductor Prueba",
        "driver_photo_base64": photo,
        "driver_rating": 4.9,
        "driver_trips": 120,
        "vehicle_model": "Toyota Yaris",
        "vehicle_plate": "ABC-123",
        "vehicle_color": "Plata",
    }


def test_live_trip_state_machine_and_location(client):
    created = client.post(
        "/api/v1/ride-requests",
        json=_ride_payload(),
    )
    assert created.status_code == 201, created.text
    request_id = created.json()["id"]

    accepted = client.post(
        f"/api/v1/ride-requests/{request_id}/accept",
        json=_driver_profile(),
    )
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["status"] == "accepted"
    assert accepted.json()["accepted_at"]

    with client.websocket_connect(
        f"/api/v1/ride-requests/ws/request/{request_id}"
    ) as websocket:
        initial = websocket.receive_json()
        assert initial["event"] == "ride_updated"
        assert initial["ride"]["status"] == "accepted"

        location = client.post(
            f"/api/v1/ride-requests/{request_id}/driver-location",
            json={
                "latitude": -9.53010,
                "longitude": -77.52920,
            },
        )
        assert location.status_code == 200, location.text
        assert location.json()["status"] == "driver_en_route"

        location_event = websocket.receive_json()
        assert location_event["event"] == "driver_location"
        assert location_event["status"] == "driver_en_route"

        status_event = websocket.receive_json()
        assert status_event["event"] == "ride_updated"
        assert status_event["ride"]["status"] == "driver_en_route"

        arrived = client.post(
            f"/api/v1/ride-requests/{request_id}/arrived"
        )
        assert arrived.status_code == 200, arrived.text
        assert arrived.json()["status"] == "driver_arrived"

        arrived_event = websocket.receive_json()
        assert arrived_event["event"] == "ride_updated"
        assert arrived_event["ride"]["status"] == "driver_arrived"

        started = client.post(
            f"/api/v1/ride-requests/{request_id}/start"
        )
        assert started.status_code == 200, started.text
        assert started.json()["status"] == "in_progress"

        started_event = websocket.receive_json()
        assert started_event["event"] == "ride_updated"
        assert started_event["ride"]["status"] == "in_progress"

        second_location = client.post(
            f"/api/v1/ride-requests/{request_id}/driver-location",
            json={
                "latitude": -9.50020,
                "longitude": -77.53310,
            },
        )
        assert second_location.status_code == 200
        assert second_location.json()["driver_lat"] == -9.50020

        second_location_event = websocket.receive_json()
        assert second_location_event["event"] == "driver_location"

        completed = client.post(
            f"/api/v1/ride-requests/{request_id}/complete"
        )
        assert completed.status_code == 200, completed.text
        assert completed.json()["status"] == "completed"
        assert completed.json()["completed_at"]

        completed_event = websocket.receive_json()
        assert completed_event["event"] == "ride_updated"
        assert completed_event["ride"]["status"] == "completed"

    pending = client.get("/api/v1/ride-requests/pending")
    assert pending.status_code == 200
    assert request_id not in {
        item["id"]
        for item in pending.json()
    }


def test_invalid_trip_transition_is_rejected(client):
    created = client.post(
        "/api/v1/ride-requests",
        json=_ride_payload(),
    )
    request_id = created.json()["id"]

    accepted = client.post(
        f"/api/v1/ride-requests/{request_id}/accept",
        json=_driver_profile(),
    )
    assert accepted.status_code == 200

    completed = client.post(
        f"/api/v1/ride-requests/{request_id}/complete"
    )
    assert completed.status_code == 409
