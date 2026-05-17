from __future__ import annotations

import asyncio
from typing import Any
from uuid import UUID

from supabase import Client


async def _x(fn):
    return await asyncio.to_thread(fn)


async def insert_message(
    client: Client,
    *,
    thread_id: UUID,
    user_id: UUID,
    role: str,
    content: str,
    sources: list[Any],
) -> dict[str, Any]:
    def _():
        resp = (
            client.table("chat_messages")
            .insert(
                {
                    "thread_id": str(thread_id),
                    "user_id": str(user_id),
                    "role": role,
                    "content": content,
                    "sources": sources,
                }
            )
            .execute()
        )
        row = resp.data[0]
        return dict(row)

    return await _x(_)


async def list_messages(
    client: Client, *, thread_id: UUID, user_id: UUID, limit: int, offset: int
) -> list[dict[str, Any]]:
    def _():
        resp = (
            client.table("chat_messages")
            .select("*")
            .eq("thread_id", str(thread_id))
            .eq("user_id", str(user_id))
            .order("created_at", desc=False)
            .range(offset, offset + limit - 1)
            .execute()
        )
        rows = getattr(resp, "data", None) or []
        return [dict(r) for r in rows]

    return await _x(_)


async def recent_messages(
    client: Client,
    *,
    thread_id: UUID,
    user_id: UUID,
    limit: int,
) -> list[dict[str, Any]]:
    """Return the most recent ``limit`` messages in chronological order.

    Uses a descending fetch + reverse so we hit the index efficiently
    when the thread has many turns, then return oldest-first to make
    the caller's life easier when building Gemini Contents.
    """
    if limit <= 0:
        return []

    def _():
        resp = (
            client.table("chat_messages")
            .select("id,role,content,created_at")
            .eq("thread_id", str(thread_id))
            .eq("user_id", str(user_id))
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        rows = getattr(resp, "data", None) or []
        return [dict(r) for r in rows]

    rows = await _x(_)
    rows.reverse()
    return rows
