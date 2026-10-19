"""initial schema

Revision ID: 0001_initial_schema
Revises:
Create Date: 2026-10-19

Baseline schema generated from the SQLAlchemy models.

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial_schema"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
        op.create_table('grammar_lessons',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('slug', sa.String(length=100), nullable=False),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('level', sa.String(length=10), nullable=False),
        sa.Column('summary', sa.Text(), nullable=False),
        sa.Column('content_markdown', sa.Text(), nullable=False),
        sa.Column('formula', sa.String(length=255), nullable=True),
        sa.Column('examples', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('practice_questions', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment='List of quiz questions for immediate practice'),
        sa.Column('order_index', sa.Integer(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_grammar_lessons_slug'), 'grammar_lessons', ['slug'], unique=True)
        op.create_table('placement_questions',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('skill', sa.String(length=50), nullable=False, comment='vocabulary, grammar, reading, listening'),
        sa.Column('difficulty_level', sa.String(length=10), nullable=False, comment='A1, A2, B1, B2, C1'),
        sa.Column('question_text', sa.Text(), nullable=False),
        sa.Column('context_text', sa.Text(), nullable=True, comment='Reading passage or context if applicable'),
        sa.Column('audio_url', sa.String(length=500), nullable=True, comment='Audio URL for listening questions'),
        sa.Column('options', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment="List of options: ['A', 'B', 'C', 'D']"),
        sa.Column('correct_option', sa.Integer(), nullable=False, comment='Index of correct option (0-indexed)'),
        sa.Column('explanation', sa.Text(), nullable=True, comment='Detailed explanation of the correct answer'),
        sa.Column('order_index', sa.Integer(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_placement_questions_difficulty_level'), 'placement_questions', ['difficulty_level'], unique=False)
        op.create_index(op.f('ix_placement_questions_skill'), 'placement_questions', ['skill'], unique=False)
        op.create_table('pronunciation_drills',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('drill_type', sa.String(length=50), nullable=False),
        sa.Column('difficulty', sa.String(length=10), nullable=False, comment='CEFR level: A1, A2, B1, B2, C1'),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('ipa_transcription', sa.Text(), nullable=True),
        sa.Column('native_audio_url', sa.String(length=500), nullable=True),
        sa.Column('target_phonemes', postgresql.JSONB(astext_type=sa.Text()), nullable=True, comment='List of IPA phonemes this drill targets'),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_table('users',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('password_hash', sa.String(length=255), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('avatar_url', sa.String(length=500), nullable=True),
        sa.Column('current_level', sa.String(length=10), nullable=True),
        sa.Column('target_level', sa.String(length=10), nullable=True),
        sa.Column('learning_goal', sa.String(length=100), nullable=True),
        sa.Column('daily_learning_minutes', sa.Integer(), nullable=False),
        sa.Column('streak', sa.Integer(), nullable=False),
        sa.Column('total_xp', sa.Integer(), nullable=False),
        sa.Column('has_completed_onboarding', sa.Boolean(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
        op.create_table('vocabulary_topics',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('slug', sa.String(length=100), nullable=False),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('icon_name', sa.String(length=50), nullable=False),
        sa.Column('level', sa.String(length=10), nullable=False),
        sa.Column('total_words', sa.Integer(), nullable=False),
        sa.Column('order_index', sa.Integer(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_vocabulary_topics_slug'), 'vocabulary_topics', ['slug'], unique=True)
        op.create_table('ai_tutor_sessions',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('persona', sa.String(length=50), nullable=False, comment='sarah (friendly), harrison (business), emma (ielts)'),
        sa.Column('topic', sa.String(length=100), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_ai_tutor_sessions_user_id'), 'ai_tutor_sessions', ['user_id'], unique=False)
        op.create_table('ai_writing_submissions',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('topic', sa.String(length=200), nullable=False),
        sa.Column('user_text', sa.Text(), nullable=False),
        sa.Column('overall_score', sa.Float(), nullable=False),
        sa.Column('cefr_level', sa.String(length=10), nullable=False),
        sa.Column('ielts_equivalent', sa.Float(), nullable=False),
        sa.Column('grammar_feedback', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment='List of grammar errors and corrections'),
        sa.Column('vocab_suggestions', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment='Lexical improvements and advanced phrasing'),
        sa.Column('general_comment', sa.Text(), nullable=False),
        sa.Column('revised_text', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_ai_writing_submissions_user_id'), 'ai_writing_submissions', ['user_id'], unique=False)
        op.create_table('speaking_sessions',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('session_type', sa.String(length=50), nullable=False),
        sa.Column('reference_text', sa.Text(), nullable=False, comment='The target sentence/passage the user should read.'),
        sa.Column('overall_score', sa.Float(), nullable=True),
        sa.Column('fluency_score', sa.Float(), nullable=True),
        sa.Column('accuracy_score', sa.Float(), nullable=True),
        sa.Column('completeness_score', sa.Float(), nullable=True),
        sa.Column('prosody_score', sa.Float(), nullable=True),
        sa.Column('recognised_text', sa.Text(), nullable=True),
        sa.Column('word_scores', postgresql.JSONB(astext_type=sa.Text()), nullable=True, comment='List of {word, accuracy_score, error_type, phonemes: [{phoneme, score}]}'),
        sa.Column('feedback', sa.Text(), nullable=True),
        sa.Column('improvement_tips', postgresql.JSONB(astext_type=sa.Text()), nullable=True, comment='List of actionable pronunciation tips'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_speaking_sessions_user_id'), 'speaking_sessions', ['user_id'], unique=False)
        op.create_table('user_grammar_progress',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('lesson_id', sa.UUID(), nullable=False),
        sa.Column('score', sa.Float(), nullable=False),
        sa.Column('is_completed', sa.Boolean(), nullable=False),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['lesson_id'], ['grammar_lessons.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_user_grammar_progress_lesson_id'), 'user_grammar_progress', ['lesson_id'], unique=False)
        op.create_index(op.f('ix_user_grammar_progress_user_id'), 'user_grammar_progress', ['user_id'], unique=False)
        op.create_table('user_profiles',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('learning_goals', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('interested_topics', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('skill_scores', postgresql.JSONB(astext_type=sa.Text()), nullable=True, comment='Per-skill scores: vocabulary, grammar, listening, etc.'),
        sa.Column('weaknesses', postgresql.JSONB(astext_type=sa.Text()), nullable=True, comment='Detected weak areas from AI analysis'),
        sa.Column('last_placement_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id')
        )
        op.create_table('user_test_submissions',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('total_questions', sa.Integer(), nullable=False),
        sa.Column('correct_count', sa.Integer(), nullable=False),
        sa.Column('score_percentage', sa.Float(), nullable=False),
        sa.Column('assessed_level', sa.String(length=10), nullable=False),
        sa.Column('skill_breakdown', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment='Breakdown by skill: {vocabulary: 80, grammar: 60, ...}'),
        sa.Column('user_answers', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment='List of {question_id, selected_option, is_correct}'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_user_test_submissions_user_id'), 'user_test_submissions', ['user_id'], unique=False)
        op.create_table('vocabulary_words',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('topic_id', sa.UUID(), nullable=False),
        sa.Column('word', sa.String(length=100), nullable=False),
        sa.Column('phonetic', sa.String(length=100), nullable=False),
        sa.Column('part_of_speech', sa.String(length=30), nullable=False),
        sa.Column('meaning_vi', sa.Text(), nullable=False),
        sa.Column('meaning_en', sa.Text(), nullable=False),
        sa.Column('example_sentence', sa.Text(), nullable=False),
        sa.Column('example_translation', sa.Text(), nullable=False),
        sa.Column('audio_url', sa.String(length=500), nullable=True),
        sa.Column('image_url', sa.String(length=500), nullable=True),
        sa.Column('level', sa.String(length=10), nullable=False),
        sa.ForeignKeyConstraint(['topic_id'], ['vocabulary_topics.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_vocabulary_words_topic_id'), 'vocabulary_words', ['topic_id'], unique=False)
        op.create_index(op.f('ix_vocabulary_words_word'), 'vocabulary_words', ['word'], unique=False)
        op.create_table('ai_tutor_messages',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('session_id', sa.UUID(), nullable=False),
        sa.Column('role', sa.String(length=20), nullable=False, comment='user or assistant'),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('corrections', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment='List of {original, correction, explanation_vi}'),
        sa.Column('suggested_replies', postgresql.JSONB(astext_type=sa.Text()), nullable=False, comment='Follow-up quick reply suggestions for learner'),
        sa.Column('audio_url', sa.String(length=500), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['session_id'], ['ai_tutor_sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_ai_tutor_messages_session_id'), 'ai_tutor_messages', ['session_id'], unique=False)
        op.create_table('audio_recordings',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('session_id', sa.UUID(), nullable=False),
        sa.Column('audio_type', sa.String(length=20), nullable=False),
        sa.Column('file_url', sa.String(length=500), nullable=False),
        sa.Column('file_format', sa.String(length=10), nullable=False),
        sa.Column('duration_seconds', sa.Float(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['session_id'], ['speaking_sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_audio_recordings_session_id'), 'audio_recordings', ['session_id'], unique=False)
        op.create_table('user_word_progress',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('word_id', sa.UUID(), nullable=False),
        sa.Column('repetition_count', sa.Integer(), nullable=False),
        sa.Column('interval_days', sa.Integer(), nullable=False),
        sa.Column('ease_factor', sa.Float(), nullable=False),
        sa.Column('last_reviewed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('next_review_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, comment='new, learning, reviewing, mastered'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['word_id'], ['vocabulary_words.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_user_word_progress_next_review_at'), 'user_word_progress', ['next_review_at'], unique=False)
        op.create_index(op.f('ix_user_word_progress_user_id'), 'user_word_progress', ['user_id'], unique=False)
        op.create_index(op.f('ix_user_word_progress_word_id'), 'user_word_progress', ['word_id'], unique=False)


def downgrade() -> None:
        op.drop_index(op.f('ix_user_word_progress_word_id'), table_name='user_word_progress')
        op.drop_index(op.f('ix_user_word_progress_user_id'), table_name='user_word_progress')
        op.drop_index(op.f('ix_user_word_progress_next_review_at'), table_name='user_word_progress')
        op.drop_table('user_word_progress')
        op.drop_index(op.f('ix_audio_recordings_session_id'), table_name='audio_recordings')
        op.drop_table('audio_recordings')
        op.drop_index(op.f('ix_ai_tutor_messages_session_id'), table_name='ai_tutor_messages')
        op.drop_table('ai_tutor_messages')
        op.drop_index(op.f('ix_vocabulary_words_word'), table_name='vocabulary_words')
        op.drop_index(op.f('ix_vocabulary_words_topic_id'), table_name='vocabulary_words')
        op.drop_table('vocabulary_words')
        op.drop_index(op.f('ix_user_test_submissions_user_id'), table_name='user_test_submissions')
        op.drop_table('user_test_submissions')
        op.drop_table('user_profiles')
        op.drop_index(op.f('ix_user_grammar_progress_user_id'), table_name='user_grammar_progress')
        op.drop_index(op.f('ix_user_grammar_progress_lesson_id'), table_name='user_grammar_progress')
        op.drop_table('user_grammar_progress')
        op.drop_index(op.f('ix_speaking_sessions_user_id'), table_name='speaking_sessions')
        op.drop_table('speaking_sessions')
        op.drop_index(op.f('ix_ai_writing_submissions_user_id'), table_name='ai_writing_submissions')
        op.drop_table('ai_writing_submissions')
        op.drop_index(op.f('ix_ai_tutor_sessions_user_id'), table_name='ai_tutor_sessions')
        op.drop_table('ai_tutor_sessions')
        op.drop_index(op.f('ix_vocabulary_topics_slug'), table_name='vocabulary_topics')
        op.drop_table('vocabulary_topics')
        op.drop_index(op.f('ix_users_email'), table_name='users')
        op.drop_table('users')
        op.drop_table('pronunciation_drills')
        op.drop_index(op.f('ix_placement_questions_skill'), table_name='placement_questions')
        op.drop_index(op.f('ix_placement_questions_difficulty_level'), table_name='placement_questions')
        op.drop_table('placement_questions')
        op.drop_index(op.f('ix_grammar_lessons_slug'), table_name='grammar_lessons')
        op.drop_table('grammar_lessons')
