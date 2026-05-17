import asyncio

from fastapi import APIRouter

from app.api.deps import SbServiceDep, UserDep
from app.schemas.auth import MeResponse

router = APIRouter(tags=["auth"])


@router.get("/auth/me", response_model=MeResponse)
async def me(user: UserDep, svc: SbServiceDep) -> MeResponse:
    billing = await _billing_for_user(svc, str(user.id))
    return MeResponse(
        user_id=user.id,
        email=user.email,
        plan=billing.get("plan", "free"),
        subscription_status=billing.get("status"),
    )


async def _billing_for_user(svc, user_id: str) -> dict:
    def _run():
        return (
            svc.table("user_subscriptions")
            .select("plan,status")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )

    try:
        resp = await asyncio.to_thread(_run)
    except Exception:
        return {}

    rows = getattr(resp, "data", None) or []
    return rows[0] if rows else {}
