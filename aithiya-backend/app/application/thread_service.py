from __future__ import annotations

from uuid import UUID

from app.core.exceptions import NotFoundError
from app.infrastructure.db.repositories import threads_repo
from supabase import Client


async def create_thread(client: Client, *, user_id: UUID, title: str) -> dict:
    return await threads_repo.insert_thread(client, user_id=user_id, title=title)


async def list_owned(client: Client, *, user_id: UUID, limit: int, offset: int) -> list[dict]:
    return await threads_repo.list_threads(client, user_id=user_id, limit=limit, offset=offset)


async def require_owned(client: Client, *, thread_id: UUID, user_id: UUID) -> dict:
    row = await threads_repo.select_thread_owned(client, thread_id=thread_id, user_id=user_id)
    if not row:
        raise NotFoundError("Thread not found")
    return row


async def update_title(client: Client, *, thread_id: UUID, user_id: UUID, title: str) -> dict:
    await require_owned(client, thread_id=thread_id, user_id=user_id)
    row = await threads_repo.update_thread(
        client,
        thread_id=thread_id,
        user_id=user_id,
        title=title,
    )
    if not row:
        raise NotFoundError("Unable to update thread")
    return row


async def archive_thread(client: Client, *, thread_id: UUID, user_id: UUID) -> dict:
    row = await threads_repo.soft_delete_thread(client, thread_id=thread_id, user_id=user_id)
    if not row:
        raise NotFoundError("Unable to archive thread")
    return row
