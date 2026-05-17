import asyncio

import jwt
from jwt import PyJWKClient

from app.core.config import Settings
from app.core.exceptions import AuthError


class JWTClaims(dict):
    @property
    def sub(self) -> str:
        return str(self["sub"])

    @property
    def email(self) -> str | None:
        v = self.get("email")
        return str(v) if v is not None else None


_jwk_clients: dict[str, PyJWKClient] = {}


def _get_jwk_client(jwks_url: str) -> PyJWKClient:
    client = _jwk_clients.get(jwks_url)
    if client is None:
        client = PyJWKClient(jwks_url, cache_keys=True, lifespan=3600)
        _jwk_clients[jwks_url] = client
    return client


async def verify_access_token(raw_token: str, settings: Settings) -> JWTClaims:
    try:
        client = _get_jwk_client(settings.supabase_jwks_url)
        signing_key = await asyncio.to_thread(client.get_signing_key_from_jwt, raw_token)
        payload = jwt.decode(
            raw_token,
            signing_key.key,
            algorithms=["ES256"],
            audience=settings.supabase_jwt_audience,
            options={"require": ["exp", "sub"]},
        )
        return JWTClaims(payload)
    except jwt.PyJWTError as exc:
        raise AuthError("Invalid or expired token") from exc
