from app.api.v1.endpoints.ride_requests import _cancellation_policy


def test_searching_is_still_reviewed_but_has_no_driver_credits():
    policy = _cancellation_policy(
        "searching",
        credits_reserved=0,
    )
    assert policy["review_required"] is True
    assert policy["admin_status"] == "pending"
    assert policy["credits_status"] == "none"
    assert policy["credits_consumed"] == 0


def test_accepted_holds_reserved_credits_for_admin():
    policy = _cancellation_policy(
        "accepted",
        credits_reserved=12,
    )
    assert policy["review_required"] is True
    assert policy["admin_status"] == "pending"
    assert policy["credits_status"] == "held_review"
    assert policy["credits_consumed"] == 0
    assert policy["policy"] == "admin_review_hold"


def test_driver_arrived_does_not_auto_release():
    policy = _cancellation_policy(
        "driver_arrived",
        credits_reserved=10,
    )
    assert policy["credits_status"] == "held_review"
    assert policy["credits_consumed"] == 0
    assert policy["review_required"] is True


def test_started_trip_does_not_auto_consume_or_release():
    policy = _cancellation_policy(
        "in_progress",
        credits_reserved=10,
    )
    assert policy["review_required"] is True
    assert policy["admin_status"] == "pending"
    assert policy["credits_status"] == "held_review"
    assert policy["credits_consumed"] == 0


def test_arrival_reported_is_admin_review():
    policy = _cancellation_policy(
        "arrival_reported",
        credits_reserved=8,
    )
    assert policy["review_required"] is True
    assert policy["credits_status"] == "held_review"
    assert policy["credits_consumed"] == 0
