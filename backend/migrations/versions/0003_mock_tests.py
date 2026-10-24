"""mock test attempts

Revision ID: 0003_mock_tests
Revises: 0002_grammar_backend
Create Date: 2026-10-24

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0003_mock_tests"
down_revision: Union[str, None] = "0002_grammar_backend"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mock_test_attempts",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=True),
        sa.Column("set_id", sa.String(length=64), nullable=False),
        sa.Column(
            "test_type",
            sa.String(length=16),
            server_default="academic",
            nullable=False,
        ),
        sa.Column("mode", sa.String(length=16), server_default="strict", nullable=False),
        sa.Column(
            "status",
            sa.String(length=16),
            server_default="in_progress",
            nullable=False,
        ),
        sa.Column(
            "started_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "section_started_at",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "section_scores",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "raw_scores",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "answers",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "flagged",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column("overall_band", sa.Float(), nullable=True),
        sa.Column("xp_awarded", sa.Integer(), server_default="0", nullable=False),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_mock_test_attempts_user_id"),
        "mock_test_attempts",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_test_attempts_set_id"),
        "mock_test_attempts",
        ["set_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_mock_test_attempts_set_id"), table_name="mock_test_attempts"
    )
    op.drop_index(
        op.f("ix_mock_test_attempts_user_id"), table_name="mock_test_attempts"
    )
    op.drop_table("mock_test_attempts")
