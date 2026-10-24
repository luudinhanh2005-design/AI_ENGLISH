from fastapi import Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
import time
import logging

logger = logging.getLogger(__name__)


def setup_cors(
    app,
    origins: list[str] | None = None,
    allow_localhost: bool = True,
):
    """Configure CORS middleware.

    Localhost origins are convenient for development but must not be accepted
    in production. Callers should pass ``allow_localhost=False`` there.
    """
    allowed_origins = origins if origins is not None else (["*"] if allow_localhost else [])
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_origin_regex=(
            r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
            if allow_localhost
            else None
        ),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Log all incoming requests with timing."""

    async def dispatch(self, request: Request, call_next):
        start_time = time.time()

        response = await call_next(request)

        process_time = time.time() - start_time
        logger.info(
            f"{request.method} {request.url.path} "
            f"â†’ {response.status_code} "
            f"({process_time:.3f}s)"
        )

        response.headers["X-Process-Time"] = str(round(process_time, 3))
        return response


class ErrorHandlingMiddleware(BaseHTTPMiddleware):
    """Catch unhandled exceptions and return JSON error responses."""

    async def dispatch(self, request: Request, call_next):
        try:
            response = await call_next(request)
            return response
        except Exception as e:
            logger.exception(f"Unhandled error: {e}")
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "detail": "Internal server error",
                    "type": "server_error",
                },
            )
