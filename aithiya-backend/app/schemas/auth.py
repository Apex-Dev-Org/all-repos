from uuid import UUID

from pydantic import BaseModel


class MeResponse(BaseModel):
    user_id: UUID
    email: str | None = None
    plan: str = "free"
    subscription_status: str | None = None
