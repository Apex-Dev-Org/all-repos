from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel


class LegalDocumentRow(BaseModel):
    id: UUID
    title: str
    content: str
    metadata: dict[str, Any]
    embedding: Any | None = None
    is_in_effect: bool
    created_by: UUID | None
    created_at: datetime
    updated_at: datetime


class ListedDocument(BaseModel):
    id: UUID
    title: str
    metadata: dict[str, Any]
    is_in_effect: bool
    created_at: datetime


class LegalDocumentsPage(BaseModel):
    items: list[ListedDocument]


class BatchDelete(BaseModel):
    ids: list[UUID]


class DeletedCount(BaseModel):
    deleted: int
