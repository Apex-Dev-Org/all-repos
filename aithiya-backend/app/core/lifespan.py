import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from google import genai

from app.core.config import get_settings
from app.core.logging import configure_logging, log
from app.infrastructure.auth.jwt_verifier import _get_jwk_client
from app.infrastructure.db.supabase_client import create_service_supabase


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    configure_logging(settings.log_level)
    app.state.settings = settings
    app.state.genai_client = genai.Client(api_key=settings.gemini_api_key)
    app.state.http_client = httpx.AsyncClient(timeout=120.0)
    app.state.supabase_service = create_service_supabase(settings)
    try:
        jwk_client = _get_jwk_client(settings.supabase_jwks_url)
        await asyncio.to_thread(jwk_client.get_signing_keys)
    except Exception as exc:
        log().warning("jwks_prewarm_failed", error=str(exc))
    yield
    await app.state.http_client.aclose()
