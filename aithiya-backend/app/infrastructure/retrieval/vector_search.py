from __future__ import annotations

import asyncio
from typing import Any
from uuid import UUID

from app.core.config import Settings
from app.core.exceptions import DatabaseError
from app.domain.retrieval import RetrievedChunk
from app.infrastructure.db.supabase_client import rpc_sync
from supabase import Client


async def match_documents(
    client: Client,
    settings: Settings,
    query_embedding: list[float],
    match_count: int | None = None,
    only_in_effect: bool | None = None,
    filter_metadata: dict[str, Any] | None = None,
) -> list[RetrievedChunk]:
    k = match_count or settings.rag_top_k
    only = settings.rag_only_in_effect if only_in_effect is None else only_in_effect
    flt: dict[str, Any] = filter_metadata or {}

    def _call():
        return rpc_sync(
            client,
            "match_documents",
            {
                "query_embedding": query_embedding,
                "match_count": k,
                "only_in_effect": only,
                "filter": flt,
            },
        )

    try:
        res = await asyncio.to_thread(_call)
    except Exception as exc:
        raise DatabaseError("Vector search failed") from exc

    rows = getattr(res, "data", None) or []
    out: list[RetrievedChunk] = []
    for row in rows:
        out.append(
            RetrievedChunk(
                doc_id=UUID(str(row["id"])),
                title=str(row.get("title") or ""),
                content=str(row.get("content") or ""),
                metadata=dict(row.get("metadata") or {}),
                similarity=float(row.get("similarity") or 0.0),
            )
        )
    return out
