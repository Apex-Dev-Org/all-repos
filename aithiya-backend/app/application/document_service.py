from __future__ import annotations

from uuid import UUID

from app.infrastructure.db.repositories import documents_repo
from supabase import Client


async def list_summaries(client: Client, *, limit: int, offset: int, only_in_effect: bool | None):
    return await documents_repo.list_documents(
        client,
        limit=limit,
        offset=offset,
        only_in_effect=only_in_effect,
    )


async def remove(client: Client, *, doc_id: UUID) -> None:
    await documents_repo.delete_document(client, doc_id=doc_id)
