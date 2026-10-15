from app.api.v1.endpoints.ride_requests import (
    _cancellation_policy,
    _cancellation_reason_label,
)


def test_before_assignment_has_no_charge():
    policy = _cancellation_policy(
        "searching",
        credits_reserved=0,
    )
    assert policy["policy"] == "no_charge"
    assert policy["credits_status"] == "none"
    assert policy["review_required"] is False


def test_prestart_releases_reserved_credits():
    policy = _cancellation_policy(
        "driver_en_route",
        credits_reserved=12,
    )
    assert policy["policy"] == "release_reserved"
    assert policy["credits_status"] == "released"
    assert policy["credits_consumed"] == 0
    assert policy["review_required"] is False


def test_driver_arrived_still_releases_before_start():
    policy = _cancellation_policy(
        "driver_arrived",
        credits_reserved=10,
    )
    assert policy["credits_status"] == "released"
    assert policy["credits_consumed"] == 0


def test_started_trip_requires_admin_review():
    policy = _cancellation_policy(
        "in_progress",
        credits_reserved=10,
    )
    assert policy["policy"] == "admin_review"
    assert policy["credits_status"] == "review"
    assert policy["credits_consumed"] == 0
    assert policy["review_required"] is True
    assert policy["admin_status"] == "pending"


def test_reason_labels_are_server_controlled():
    assert (
        _cancellation_reason_label(
            "driver",
            "passenger_no_show",
        )
        == "El pasajero no aparece"
    )
    assert (
        _cancellation_reason_label(
            "passenger",
            "driver_delay",
        )
        == "El conductor está demorando demasiado"
    )
