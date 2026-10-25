"""vocabulary content fields and ordering

Revision ID: 0006_vocabulary_content
Revises: 0005_placement_v2
Create Date: 2026-10-25

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0006_vocabulary_content"
down_revision: Union[str, None] = "0005_placement_v2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "vocabulary_words",
        sa.Column(
            "collocations",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "vocabulary_words",
        sa.Column(
            "synonyms",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "vocabulary_words",
        sa.Column(
            "antonyms",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "vocabulary_words",
        sa.Column(
            "tags",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "vocabulary_words",
        sa.Column(
            "order_index",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
    )
    op.create_index(
        "ix_vocabulary_words_topic_id_level",
        "vocabulary_words",
        ["topic_id", "level"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_vocabulary_words_topic_id_level", table_name="vocabulary_words")
    op.drop_column("vocabulary_words", "order_index")
    op.drop_column("vocabulary_words", "tags")
    op.drop_column("vocabulary_words", "antonyms")
    op.drop_column("vocabulary_words", "synonyms")
    op.drop_column("vocabulary_words", "collocations")
