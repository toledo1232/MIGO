from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.session import UserSession


class SessionRepository:
    def __init__(
        self,
        db: Session,
    ) -> None:
        self.db = db

    def create(
        self,
        *,
        user_id,
        token_hash: str,
        expires_at: datetime,
        device_name: str | None,
        platform: str | None,
    ) -> UserSession:
        item = UserSession(
            user_id=user_id,
            refresh_token_hash=token_hash,
            expires_at=expires_at,
            device_name=device_name,
            platform=platform,
            is_active=True,
        )

        self.db.add(item)
        self.db.commit()
        self.db.refresh(item)

        return item

    def get_by_hash(
        self,
        token_hash: str,
    ) -> UserSession | None:
        return self.db.scalar(
            select(UserSession).where(
                UserSession.refresh_token_hash
                == token_hash
            )
        )

    def rotate(
        self,
        *,
        item: UserSession,
        token_hash: str,
        expires_at: datetime,
    ) -> None:
        item.refresh_token_hash = token_hash
        item.expires_at = expires_at
        item.last_used_at = datetime.now(
            timezone.utc
        )

        self.db.commit()

    def revoke(
        self,
        item: UserSession,
    ) -> None:
        item.is_active = False
        item.revoked_at = datetime.now(
            timezone.utc
        )

        self.db.commit()

    def list_for_user(
        self,
        user_id,
    ) -> list[UserSession]:
        statement = (
            select(UserSession)
            .where(
                UserSession.user_id
                == user_id
            )
            .order_by(
                UserSession.created_at.desc()
            )
        )

        return list(
            self.db.scalars(statement)
        )

    def revoke_all_for_user(
        self,
        user_id,
    ) -> None:
        statement = select(
            UserSession
        ).where(
            UserSession.user_id
            == user_id,
            UserSession.is_active.is_(
                True
            ),
        )

        items = list(
            self.db.scalars(statement)
        )

        now = datetime.now(
            timezone.utc
        )

        for item in items:
            item.is_active = False
            item.revoked_at = now

        self.db.commit()