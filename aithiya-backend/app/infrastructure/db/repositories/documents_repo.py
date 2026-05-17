from __future__ import annotations

import asyncio
from typing import Any
from uuid import UUID

from supabase import Client


async def _x(fn):
    return await asyncio.to_thread(fn)


async def bulk_insert_documents(client: Client, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if not rows:
        return []

    def _():
        resp = client.table("legal_documents").insert(rows).execute()
        data = getattr(resp, "data", None) or []
        return [dict(r) for r in data]

    return await _x(_)


async def list_documents(
    client: Client, *, limit: int, offset: int, only_in_effect: bool | None = None
) -> list[dict[str, Any]]:
    def _():
        q = client.table("legal_documents").select("id,title,metadata,is_in_effect,created_at")
        if only_in_effect is not None:
            q = q.eq("is_in_effect", only_in_effect)
        resp = q.order("created_at", desc=True).range(offset, offset + limit - 1).execute()
        rows = getattr(resp, "data", None) or []
        return [dict(r) for r in rows]

    return await _x(_)


async def delete_document(client: Client, *, doc_id: UUID) -> None:
    def _():
        client.table("legal_documents").delete().eq("id", str(doc_id)).execute()

    await _x(_)


async def get_completed_chunk_indexes(
    client: Client, *, ingest_id: UUID
) -> set[int]:
    """Return the set of 1-based chunk_index values already stored for an ingest run."""

    def _():
        resp = (
            client.table("legal_documents")
            .select("metadata")
            .contains("metadata", {"ingest_id": str(ingest_id)})
            .execute()
        )
        rows = getattr(resp, "data", None) or []
        out: set[int] = set()
        for r in rows:
            meta = r.get("metadata") or {}
            ci = meta.get("chunk_index")
            if isinstance(ci, int):
                out.add(ci)
        return out

    return await _x(_)
