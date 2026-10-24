"""grammar backend: versioned content, idempotent attempts, XP ledger

Revision ID: 0002_grammar_backend
Revises: 0001_initial_schema
Create Date: 2026-10-23

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0002_grammar_backend"
down_revision: Union[str, None] = "0001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── User roles ──────────────────────────────────────────────
    op.add_column(
        "users",
        sa.Column("role", sa.String(length=20), server_default="user", nullable=False),
    )
    op.create_index(op.f("ix_users_role"), "users", ["role"], unique=False)
    op.execute("UPDATE users SET role = 'admin' WHERE lower(email) = 'admin@gmail.com'")

    # ── Grammar lesson content/versioning ───────────────────────
    op.add_column(
        "grammar_lessons",
        sa.Column("title_vi", sa.String(length=200), server_default="", nullable=False),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("category", sa.String(length=120), server_default="", nullable=False),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("content", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("content_hash", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("status", sa.String(length=20), server_default="published", nullable=False),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("is_beta", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column(
            "tags",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("estimated_minutes", sa.Integer(), server_default="10", nullable=False),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("created_by", sa.UUID(), nullable=True),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("updated_by", sa.UUID(), nullable=True),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "grammar_lessons",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_grammar_lessons_status"), "grammar_lessons", ["status"], unique=False)

    # ── Progress + best score / attempt counters ────────────────
    op.add_column(
        "user_grammar_progress",
        sa.Column("best_score", sa.Float(), server_default="0", nullable=False),
    )
    op.add_column(
        "user_grammar_progress",
        sa.Column("attempts_count", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column(
        "user_grammar_progress",
        sa.Column("last_attempt_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.execute(
        """
        UPDATE user_grammar_progress
        SET best_score = score,
            last_attempt_at = updated_at
        """
    )
    # Keep the best row for each user/lesson before adding the unique constraint.
    op.execute(
        """
        WITH best AS (
            SELECT user_id,
                   lesson_id,
                   MAX(score) AS max_score,
                   BOOL_OR(is_completed) AS any_completed,
                   MAX(completed_at) AS last_completed
            FROM user_grammar_progress
            GROUP BY user_id, lesson_id
        )
        UPDATE user_grammar_progress p
        SET score = best.max_score,
            best_score = best.max_score,
            is_completed = best.any_completed,
            completed_at = COALESCE(p.completed_at, best.last_completed)
        FROM best
        WHERE p.user_id = best.user_id AND p.lesson_id = best.lesson_id
        """
    )
    op.execute(
        """
        WITH ranked AS (
            SELECT id,
                   ROW_NUMBER() OVER (
                       PARTITION BY user_id, lesson_id
                       ORDER BY score DESC, updated_at DESC, id
                   ) AS rn
            FROM user_grammar_progress
        )
        DELETE FROM user_grammar_progress p
        USING ranked
        WHERE p.id = ranked.id AND ranked.rn > 1
        """
    )
    op.create_unique_constraint(
        "uq_user_grammar_progress_user_lesson",
        "user_grammar_progress",
        ["user_id", "lesson_id"],
    )

    # ── Immutable lesson versions ───────────────────────────────
    op.create_table(
        "grammar_lesson_versions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("lesson_id", sa.UUID(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("content", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("content_hash", sa.String(length=64), nullable=False),
        sa.Column("changelog", sa.Text(), server_default="", nullable=False),
        sa.Column("created_by", sa.UUID(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["lesson_id"], ["grammar_lessons.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("lesson_id", "version", name="uq_grammar_lesson_version"),
    )
    op.create_index(
        op.f("ix_grammar_lesson_versions_lesson_id"),
        "grammar_lesson_versions",
        ["lesson_id"],
        unique=False,
    )

    # ── Idempotent attempts ─────────────────────────────────────
    op.create_table(
        "grammar_attempts",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("attempt_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("lesson_id", sa.UUID(), nullable=False),
        sa.Column("lesson_version", sa.Integer(), server_default="1", nullable=False),
        sa.Column("answers", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("score", sa.Float(), server_default="0", nullable=False),
        sa.Column("correct", sa.Integer(), server_default="0", nullable=False),
        sa.Column("total", sa.Integer(), server_default="0", nullable=False),
        sa.Column("xp_awarded", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["lesson_id"], ["grammar_lessons.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "attempt_id", name="uq_grammar_attempt_user_attempt"),
    )
    op.create_index(op.f("ix_grammar_attempts_attempt_id"), "grammar_attempts", ["attempt_id"], unique=False)
    op.create_index(op.f("ix_grammar_attempts_user_id"), "grammar_attempts", ["user_id"], unique=False)
    op.create_index(op.f("ix_grammar_attempts_lesson_id"), "grammar_attempts", ["lesson_id"], unique=False)

    # ── XP ledger ───────────────────────────────────────────────
    op.create_table(
        "xp_transactions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("source_type", sa.String(length=40), nullable=False),
        sa.Column("source_id", sa.UUID(), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "source_type",
            "source_id",
            name="uq_xp_transaction_source",
        ),
    )
    op.create_index(op.f("ix_xp_transactions_user_id"), "xp_transactions", ["user_id"], unique=False)

    # ── Admin audit trail ───────────────────────────────────────
    op.create_table(
        "grammar_admin_audit",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("actor_id", sa.UUID(), nullable=True),
        sa.Column("action", sa.String(length=50), nullable=False),
        sa.Column("lesson_id", sa.UUID(), nullable=True),
        sa.Column("details", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["lesson_id"], ["grammar_lessons.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_grammar_admin_audit_actor_id"), "grammar_admin_audit", ["actor_id"], unique=False)
    op.create_index(op.f("ix_grammar_admin_audit_lesson_id"), "grammar_admin_audit", ["lesson_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_grammar_admin_audit_lesson_id"), table_name="grammar_admin_audit")
    op.drop_index(op.f("ix_grammar_admin_audit_actor_id"), table_name="grammar_admin_audit")
    op.drop_table("grammar_admin_audit")

    op.drop_index(op.f("ix_xp_transactions_user_id"), table_name="xp_transactions")
    op.drop_table("xp_transactions")

    op.drop_index(op.f("ix_grammar_attempts_lesson_id"), table_name="grammar_attempts")
    op.drop_index(op.f("ix_grammar_attempts_user_id"), table_name="grammar_attempts")
    op.drop_index(op.f("ix_grammar_attempts_attempt_id"), table_name="grammar_attempts")
    op.drop_table("grammar_attempts")

    op.drop_index(
        op.f("ix_grammar_lesson_versions_lesson_id"),
        table_name="grammar_lesson_versions",
    )
    op.drop_table("grammar_lesson_versions")

    op.drop_constraint(
        "uq_user_grammar_progress_user_lesson",
        "user_grammar_progress",
        type_="unique",
    )
    op.drop_column("user_grammar_progress", "last_attempt_at")
    op.drop_column("user_grammar_progress", "attempts_count")
    op.drop_column("user_grammar_progress", "best_score")

    op.drop_index(op.f("ix_grammar_lessons_status"), table_name="grammar_lessons")
    op.drop_column("grammar_lessons", "updated_at")
    op.drop_column("grammar_lessons", "published_at")
    op.drop_column("grammar_lessons", "reviewed_at")
    op.drop_column("grammar_lessons", "updated_by")
    op.drop_column("grammar_lessons", "created_by")
    op.drop_column("grammar_lessons", "estimated_minutes")
    op.drop_column("grammar_lessons", "tags")
    op.drop_column("grammar_lessons", "is_beta")
    op.drop_column("grammar_lessons", "version")
    op.drop_column("grammar_lessons", "status")
    op.drop_column("grammar_lessons", "content_hash")
    op.drop_column("grammar_lessons", "content")
    op.drop_column("grammar_lessons", "category")
    op.drop_column("grammar_lessons", "title_vi")

    op.drop_index(op.f("ix_users_role"), table_name="users")
    op.drop_column("users", "role")
