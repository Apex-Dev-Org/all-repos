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
    sources: list[Any] | dict[str, Any],
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
