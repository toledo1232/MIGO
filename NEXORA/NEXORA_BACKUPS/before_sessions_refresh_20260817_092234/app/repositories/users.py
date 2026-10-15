from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    def __init__(
        self,
        db: Session,
    ) -> None:
        self.db = db

    def create(
        self,
        *,
        full_name: str,
        phone: str,
        email: str,
        password_hash: str,
    ) -> User:
        normalized_phone = phone.strip()
        normalized_email = email.strip().lower()

        if self.get_by_phone(normalized_phone):
            raise ValueError(
                "PHONE_ALREADY_REGISTERED"
            )

        if self.get_by_email(normalized_email):
            raise ValueError(
                "EMAIL_ALREADY_REGISTERED"
            )

        user = User(
            full_name=full_name.strip(),
            phone=normalized_phone,
            email=normalized_email,
            password_hash=password_hash,
            account_active=True,
            driver_approved=False,
        )

        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)

        return user

    def get_by_id(
        self,
        user_id: str,
    ) -> User | None:
        try:
            return self.db.get(
                User,
                user_id,
            )
        except (TypeError, ValueError):
            return None

    def get_by_phone(
        self,
        phone: str,
    ) -> User | None:
        statement = select(User).where(
            User.phone == phone.strip()
        )

        return self.db.scalar(statement)

    def get_by_email(
        self,
        email: str,
    ) -> User | None:
        statement = select(User).where(
            User.email == email.strip().lower()
        )

        return self.db.scalar(statement)
