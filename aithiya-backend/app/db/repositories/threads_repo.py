from __future__ import annotations

import asyncio
from typing import Any
from uuid import UUID

from supabase import Client


async def _x(fn):
    return await asyncio.to_thread(fn)


async def insert_thread(client: Client, *, user_id: UUID, title: str) -> dict[str, Any]:
    def _():
        resp = (
            client.table("chat_threads").insert({"user_id": str(user_id), "title": title}).execute()
        )
        row = resp.data[0]
        return dict(row)

    return await _x(_)


async def select_thread_owned(
    client: Client,
    *,
    thread_id: UUID,
    user_id: UUID,
) -> dict[str, Any] | None:
    def _():
        resp = (
            client.table("chat_threads")
            .select("*")
            .eq("id", str(thread_id))
            .eq("user_id", str(user_id))
            .limit(1)
            .execute()
        )
        rows = getattr(resp, "data", None) or []
        return dict(rows[0]) if rows else None

    return await _x(_)


async def list_threads(
    client: Client, *, user_id: UUID, limit: int, offset: int
) -> list[dict[str, Any]]:
    def _():
        resp = (
            client.table("chat_threads")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("is_deleted", False)
            .order("updated_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        rows = getattr(resp, "data", None) or []
        return [dict(r) for r in rows]

    return await _x(_)


async def update_thread(
    client: Client,
    *,
    thread_id: UUID,
    user_id: UUID,
    title: str,
) -> dict[str, Any]:
    def _():
        resp = (
            client.table("chat_threads")
            .update({"title": title})
            .eq("id", str(thread_id))
            .eq("user_id", str(user_id))
            .execute()
        )
        rows = getattr(resp, "data", None) or []
        return dict(rows[0]) if rows else {}

    return await _x(_)


async def soft_delete_thread(
    client: Client,
    *,
    thread_id: UUID,
    user_id: UUID,
) -> dict[str, Any]:
    def _():
        resp = (
            client.table("chat_threads")
            .update({"is_deleted": True})
            .eq("id", str(thread_id))
            .eq("user_id", str(user_id))
            .execute()
        )
        rows = getattr(resp, "data", None) or []
        return dict(rows[0]) if rows else {}

    return await _x(_)
