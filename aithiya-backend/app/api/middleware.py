from __future__ import annotations

import uuid

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from pydantic import ValidationError
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address
from starlette.responses import JSONResponse
from tenacity import RetryError

from app.core.config import get_settings
from app.core.exceptions import AppError
from app.schemas.common import ErrorPayload, ErrorResponse

limiter = Limiter(key_func=get_remote_address)


async def request_id_ctx(request: Request, call_next):
    rid = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    request.state.request_id = rid
    response = await call_next(request)
    response.headers["X-Request-ID"] = rid
    return response


def setup_cors(app: FastAPI) -> None:
    settings = get_settings()
    origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins or ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


def setup_slowapi(app: FastAPI) -> None:
    app.state.limiter = limiter
    app.add_middleware(SlowAPIMiddleware)
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def app_error_handler(request: Request, exc: AppError):
        rid = getattr(request.state, "request_id", None)
        payload = ErrorPayload(
            code=exc.code,
            message=exc.message,
            request_id=rid,
            details=exc.details,
        )
        body = ErrorResponse(error=payload).model_dump()
        return JSONResponse(status_code=exc.status_code, content=body)

    @app.exception_handler(RequestValidationError)
    async def validation_handler(request: Request, exc: RequestValidationError):
        rid = getattr(request.state, "request_id", None)
        payload = ErrorPayload(
            code="validation_error",
            message="Request validation failed",
            request_id=rid,
            details={"errors": exc.errors()},
        )
        body = ErrorResponse(error=payload).model_dump()
        return JSONResponse(status_code=422, content=body)

    @app.exception_handler(ValidationError)
    async def pydantic_validation_handler(request: Request, exc: ValidationError):
        rid = getattr(request.state, "request_id", None)
        payload = ErrorPayload(
            code="validation_error",
            message="Invalid data",
            request_id=rid,
            details={"errors": exc.errors()},
        )
        body = ErrorResponse(error=payload).model_dump()
        return JSONResponse(status_code=422, content=body)

    @app.exception_handler(RetryError)
    async def retry_error_handler(request: Request, exc: RetryError):
        inner: BaseException | None = None
        if exc.last_attempt is not None:
            try:
                inner = exc.last_attempt.exception()
            except Exception:
                inner = None
        if isinstance(inner, AppError):
            return await app_error_handler(request, inner)
        rid = getattr(request.state, "request_id", None)
        payload = ErrorPayload(
            code="upstream_error",
            message="Upstream service exhausted retries",
            request_id=rid,
            details={"cause": str(inner) if inner else None},
        )
        body = ErrorResponse(error=payload).model_dump()
        return JSONResponse(status_code=502, content=body)


def configure_http(app: FastAPI) -> None:
    setup_cors(app)
    app.middleware("http")(request_id_ctx)
    setup_slowapi(app)
    register_exception_handlers(app)
