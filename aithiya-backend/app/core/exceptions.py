from typing import Any


class AppError(Exception):
    code = "domain_error"
    status_code = 500

    def __init__(self, message: str, *, details: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details


class ValidationAppError(AppError):
    code = "validation_error"
    status_code = 422


class UnsupportedMediaAppError(AppError):
    code = "unsupported_media_type"
    status_code = 415


class AuthError(AppError):
    code = "unauthorized"
    status_code = 401


class ForbiddenError(AppError):
    code = "forbidden"
    status_code = 403


class NotFoundError(AppError):
    code = "not_found"
    status_code = 404


class UpstreamAIError(AppError):
    code = "upstream_ai_error"
    status_code = 502


class EmbedQuotaError(UpstreamAIError):
    code = "embed_quota_exhausted"
    status_code = 503


class DatabaseError(AppError):
    code = "database_error"
    status_code = 502


class IngestionError(AppError):
    code = "ingestion_error"
    status_code = 400
