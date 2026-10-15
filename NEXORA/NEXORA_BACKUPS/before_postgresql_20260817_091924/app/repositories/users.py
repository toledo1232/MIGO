from dataclasses import dataclass
from uuid import uuid4


@dataclass
class UserRecord:
    id: str
    full_name: str
    phone: str
    email: str
    password_hash: str
    account_active: bool
    driver_approved: bool


class InMemoryUserRepository:
    def __init__(self) -> None:
        self._by_id: dict[str, UserRecord] = {}
        self._by_phone: dict[str, str] = {}
        self._by_email: dict[str, str] = {}

    def create(
        self,
        *,
        full_name: str,
        phone: str,
        email: str,
        password_hash: str,
    ) -> UserRecord:
        normalized_phone = phone.strip()
        normalized_email = email.strip().lower()

        if normalized_phone in self._by_phone:
            raise ValueError(
                "PHONE_ALREADY_REGISTERED"
            )

        if normalized_email in self._by_email:
            raise ValueError(
                "EMAIL_ALREADY_REGISTERED"
            )

        user = UserRecord(
            id=str(uuid4()),
            full_name=full_name.strip(),
            phone=normalized_phone,
            email=normalized_email,
            password_hash=password_hash,
            account_active=True,
            driver_approved=False,
        )

        self._by_id[user.id] = user
        self._by_phone[user.phone] = user.id
        self._by_email[user.email] = user.id

        return user

    def get_by_id(
        self,
        user_id: str,
    ) -> UserRecord | None:
        return self._by_id.get(user_id)

    def get_by_phone(
        self,
        phone: str,
    ) -> UserRecord | None:
        user_id = self._by_phone.get(
            phone.strip()
        )

        if not user_id:
            return None

        return self._by_id.get(user_id)


user_repository = InMemoryUserRepository()
