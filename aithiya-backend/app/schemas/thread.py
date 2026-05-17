from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ThreadCreate(BaseModel):
    title: str | None = Field(default="New chat", max_length=200)


class ThreadUpdate(BaseModel):
    title: str | None = Field(default=None, max_length=200)


class ThreadOut(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class ThreadList(BaseModel):
    items: list[ThreadOut]


class Pagination(BaseModel):
    limit: int = Field(default=50, ge=1, le=200)
    offset: int = Field(default=0, ge=0)


class ThreadListPaged(BaseModel):
    items: list[ThreadOut]
    total_estimate: int | None = None
