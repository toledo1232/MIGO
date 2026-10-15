"""create users table

Revision ID: 0001_users
Revises:
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0001_users"
down_revision: str | None = None
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column(
            "id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "full_name",
            sa.String(length=120),
            nullable=False,
        ),
        sa.Column(
            "phone",
            sa.String(length=20),
            nullable=False,
        ),
        sa.Column(
            "email",
            sa.String(length=320),
            nullable=False,
        ),
        sa.Column(
            "password_hash",
            sa.String(length=512),
            nullable=False,
        ),
        sa.Column(
            "account_active",
            sa.Boolean(),
            nullable=False,
        ),
        sa.Column(
            "driver_approved",
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
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_users_phone",
        "users",
        ["phone"],
        unique=True,
    )

    op.create_index(
        "ix_users_email",
        "users",
        ["email"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_users_email",
        table_name="users",
    )

    op.drop_index(
        "ix_users_phone",
        table_name="users",
    )

    op.drop_table("users")
