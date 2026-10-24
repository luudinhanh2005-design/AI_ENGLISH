from fastapi import APIRouter

from .admin_grammar import router as admin_grammar_router
from .ai import router as ai_router
from .auth import router as auth_router
from .grammar import router as grammar_router
from .mock_tests import router as mock_tests_router
from .placement import router as placement_router
from .speech import router as speech_router
from .users import router as users_router
from .vocabulary import router as vocabulary_router

router = APIRouter(prefix="/api/v1")

router.include_router(auth_router, prefix="/auth", tags=["Authentication"])
router.include_router(users_router, prefix="/users", tags=["Users"])
router.include_router(placement_router, prefix="/placement", tags=["Placement Test"])
router.include_router(vocabulary_router, prefix="/vocabulary", tags=["Vocabulary & SM-2"])
router.include_router(grammar_router, prefix="/grammar", tags=["Grammar"])
router.include_router(
    mock_tests_router,
    prefix="/mock-tests",
    tags=["IELTS Mock Test"],
)
router.include_router(
    admin_grammar_router,
    prefix="/admin/grammar",
    tags=["Grammar Admin"],
)
router.include_router(ai_router, prefix="/ai", tags=["AI Tutor & Intelligent Engine"])
router.include_router(speech_router, prefix="/speech", tags=["Speech AI & Pronunciation"])

