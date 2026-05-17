import logging
import sys

import structlog


def configure_logging(level: str) -> None:
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, level.upper(), logging.INFO),
    )
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.StackInfoRenderer(),
            structlog.dev.set_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def log():
    return structlog.get_logger("aithiya")


def bind_request_context(**kwargs: object) -> None:
    structlog.contextvars.clear_contextvars()
    for k, v in kwargs.items():
        structlog.contextvars.bind_contextvars(**{k: v})
