from uuid import UUID

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
        phone = phone.strip()
        email = email.strip().lower()

        if self.get_by_phone(phone):
            raise ValueError(
                "PHONE_ALREADY_REGISTERED"
            )

        if self.get_by_email(email):
            raise ValueError(
                "EMAIL_ALREADY_REGISTERED"
            )

        user = User(
            full_name=full_name.strip(),
            phone=phone,
            email=email,
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
            parsed_id = UUID(user_id)
        except ValueError:
            return None

        return self.db.get(
            User,
            parsed_id,
        )

    def get_by_phone(
        self,
        phone: str,
    ) -> User | None:
        return self.db.scalar(
            select(User).where(
                User.phone == phone.strip()
            )
        )

    def get_by_email(
        self,
        email: str,
    ) -> User | None:
        return self.db.scalar(
            select(User).where(
                User.email
                == email.strip().lower()
            )
        )
