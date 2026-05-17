from __future__ import annotations

import asyncio
import time
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google import genai

from app.core.config import Settings, get_settings
from app.core.exceptions import ForbiddenError
from app.domain.user import CurrentUser
from app.infrastructure.ai.gemini_client import get_genai_client
from app.infrastructure.auth.jwt_verifier import verify_access_token
from app.infrastructure.db.supabase_client import create_user_supabase
from supabase import Client

security = HTTPBearer()


def get_supabase_service(request: Request) -> Client:
    return request.app.state.supabase_service


def get_token(credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)]) -> str:
    return credentials.credentials


async def get_current_user(token: Annotated[str, Depends(get_token)]) -> CurrentUser:
    settings = get_settings()
    claims = await verify_access_token(token, settings)
    return CurrentUser(id=UUID(claims.sub), email=claims.email)


_admin_cache: dict[str, tuple[float, bool]] = {}


async def user_is_admin(user_id: UUID, svc: Client, settings: Settings) -> bool:
    key = str(user_id)
    now = time.monotonic()
    cached = _admin_cache.get(key)
    if cached and now - cached[0] < settings.admin_role_cache_ttl_s:
        return cached[1]

    def _run():
        resp = (
            svc.table("profiles").select("role,is_active").eq("id", str(user_id)).limit(1).execute()
        )
        rows = getattr(resp, "data", None) or []
        if not rows:
            return False
        row = rows[0]
        return row.get("role") == "admin" and bool(row.get("is_active", True))

    ok = await asyncio.to_thread(_run)
    _admin_cache[key] = (now, ok)
    return ok


async def require_admin(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    svc: Annotated[Client, Depends(get_supabase_service)],
) -> CurrentUser:
    settings = get_settings()
    if not await user_is_admin(user.id, svc, settings):
        raise ForbiddenError("Administrator privileges required")
    return user


async def supabase_for_user(token: Annotated[str, Depends(get_token)]) -> Client:
    settings = get_settings()
    return create_user_supabase(settings, token)


GeminiDep = Annotated[genai.Client, Depends(get_genai_client)]
SettingsDep = Annotated[Settings, Depends(get_settings)]
UserDep = Annotated[CurrentUser, Depends(get_current_user)]
SbUserDep = Annotated[Client, Depends(supabase_for_user)]
SbServiceDep = Annotated[Client, Depends(get_supabase_service)]
AdminDep = Annotated[CurrentUser, Depends(require_admin)]
