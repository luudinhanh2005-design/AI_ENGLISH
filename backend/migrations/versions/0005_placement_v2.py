"""placement test v2 (CEFR adaptive sessions, responses, reports)

Revision ID: 0005_placement_v2
Revises: 0004_user_mistakes
Create Date: 2026-10-24

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0005_placement_v2"
down_revision: Union[str, None] = "0004_user_mistakes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "placement_sessions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("mode", sa.String(length=16), nullable=False),
        sa.Column(
            "status",
            sa.String(length=20),
            server_default="in_progress",
            nullable=False,
        ),
        sa.Column(
            "blueprint_version",
            sa.String(length=20),
            server_default="2.0.0",
            nullable=False,
        ),
        sa.Column("target_exam", sa.String(length=16), nullable=True),
        sa.Column(
            "state",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_placement_sessions_user_id"),
        "placement_sessions",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_placement_sessions_mode"),
        "placement_sessions",
        ["mode"],
        unique=False,
    )
    op.create_index(
        op.f("ix_placement_sessions_status"),
        "placement_sessions",
        ["status"],
        unique=False,
    )

    op.create_table(
        "placement_responses",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("session_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("item_id", sa.String(length=64), nullable=False),
        sa.Column("skill", sa.String(length=30), nullable=False),
        sa.Column("stage", sa.Integer(), server_default="1", nullable=False),
        sa.Column(
            "answer",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column("is_correct", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("response_time_ms", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "answered_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["session_id"], ["placement_sessions.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "session_id", "item_id", name="uq_placement_response_item"
        ),
    )
    op.create_index(
        op.f("ix_placement_responses_session_id"),
        "placement_responses",
        ["session_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_placement_responses_user_id"),
        "placement_responses",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_placement_responses_item_id"),
        "placement_responses",
        ["item_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_placement_responses_skill"),
        "placement_responses",
        ["skill"],
        unique=False,
    )

    op.create_table(
        "placement_results",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("session_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("mode", sa.String(length=16), nullable=False),
        sa.Column("target_exam", sa.String(length=16), nullable=True),
        sa.Column("overall_level", sa.String(length=10), nullable=False),
        sa.Column("overall_theta", sa.Float(), server_default="0", nullable=False),
        sa.Column("overall_se", sa.Float(), server_default="0.5", nullable=False),
        sa.Column(
            "payload",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "blueprint_version",
            sa.String(length=20),
            server_default="2.0.0",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["session_id"], ["placement_sessions.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_id"),
    )
    op.create_index(
        op.f("ix_placement_results_user_id"),
        "placement_results",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_placement_results_overall_level"),
        "placement_results",
        ["overall_level"],
        unique=False,
    )
    op.create_index(
        op.f("ix_placement_results_created_at"),
        "placement_results",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_placement_results_created_at"), table_name="placement_results"
    )
    op.drop_index(
        op.f("ix_placement_results_overall_level"), table_name="placement_results"
    )
    op.drop_index(
        op.f("ix_placement_results_user_id"), table_name="placement_results"
    )
    op.drop_table("placement_results")
    op.drop_index(
        op.f("ix_placement_responses_skill"), table_name="placement_responses"
    )
    op.drop_index(
        op.f("ix_placement_responses_item_id"), table_name="placement_responses"
    )
    op.drop_index(
        op.f("ix_placement_responses_user_id"), table_name="placement_responses"
    )
    op.drop_index(
        op.f("ix_placement_responses_session_id"), table_name="placement_responses"
    )
    op.drop_table("placement_responses")
    op.drop_index(
        op.f("ix_placement_sessions_status"), table_name="placement_sessions"
    )
    op.drop_index(
        op.f("ix_placement_sessions_mode"), table_name="placement_sessions"
    )
    op.drop_index(
        op.f("ix_placement_sessions_user_id"), table_name="placement_sessions"
    )
    op.drop_table("placement_sessions")
