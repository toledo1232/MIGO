"""create user sessions

Revision ID: 0002_user_sessions
Revises: 0001_users
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0002_user_sessions"
down_revision: str | None = "0001_users"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_sessions",
        sa.Column(
            "id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "refresh_token_hash",
            sa.String(length=64),
            nullable=False,
        ),
        sa.Column(
            "device_name",
            sa.String(length=120),
            nullable=True,
        ),
        sa.Column(
            "platform",
            sa.String(length=40),
            nullable=True,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "last_used_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "expires_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "revoked_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_user_sessions_user_id",
        "user_sessions",
        ["user_id"],
        unique=False,
    )

    op.create_index(
        "ix_user_sessions_refresh_token_hash",
        "user_sessions",
        ["refresh_token_hash"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_user_sessions_refresh_token_hash",
        table_name="user_sessions",
    )

    op.drop_index(
        "ix_user_sessions_user_id",
        table_name="user_sessions",
    )

    op.drop_table(
        "user_sessions"
    )
