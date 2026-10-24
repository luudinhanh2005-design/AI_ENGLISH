"""user mistake notebook

Revision ID: 0004_user_mistakes
Revises: 0003_mock_tests
Create Date: 2026-10-24

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0004_user_mistakes"
down_revision: Union[str, None] = "0003_mock_tests"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_mistakes",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("original_text", sa.Text(), nullable=False),
        sa.Column("corrected_text", sa.Text(), nullable=False),
        sa.Column("explanation", sa.Text(), nullable=False),
        sa.Column("type", sa.String(length=30), server_default="grammar", nullable=False),
        sa.Column("source", sa.String(length=30), server_default="practice", nullable=False),
        sa.Column("repetition_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("interval_days", sa.Integer(), server_default="1", nullable=False),
        sa.Column("ease_factor", sa.Float(), server_default="2.5", nullable=False),
        sa.Column("last_reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "next_review_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("status", sa.String(length=20), server_default="new", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_user_mistakes_user_id"),
        "user_mistakes",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_user_mistakes_next_review_at"),
        "user_mistakes",
        ["next_review_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_user_mistakes_next_review_at"), table_name="user_mistakes")
    op.drop_index(op.f("ix_user_mistakes_user_id"), table_name="user_mistakes")
    op.drop_table("user_mistakes")
