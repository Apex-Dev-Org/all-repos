from datetime import datetime
from enum import StrEnum
from typing import Any
from uuid import UUID

from pydantic import BaseModel


class MessageRole(StrEnum):
    USER = "user"
    ASSISTANT = "assistant"


class ChatMessageRow(BaseModel):
    id: UUID
    thread_id: UUID
    user_id: UUID
    role: MessageRole
    content: str
    sources: list[Any] | dict[str, Any]
    created_at: datetime


class MessageList(BaseModel):
    items: list[ChatMessageRow]
