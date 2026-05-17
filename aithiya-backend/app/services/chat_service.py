from __future__ import annotations

from collections.abc import AsyncIterator
from uuid import UUID

from google import genai

from app.core.config import Settings
from app.db.repositories import messages_repo
from app.schemas.chat import ChatRequest, ChatResponse, Citation
from app.services import rag_service, thread_service
from app.utils.streaming import sse_data
from supabase import Client


async def complete_chat_exchange(
    *,
    client: Client,
    gemini: genai.Client,
    settings: Settings,
    user_id: UUID,
    body: ChatRequest,
) -> ChatResponse:
    if body.thread_id is None:
        tid_row = await thread_service.create_thread(
            client,
            user_id=user_id,
            title=body.message[:120],
        )
        thread_id = UUID(str(tid_row["id"]))
    else:
        await thread_service.require_owned(client, thread_id=body.thread_id, user_id=user_id)
        thread_id = body.thread_id

    um = await messages_repo.insert_message(
        client,
        thread_id=thread_id,
        user_id=user_id,
        role="user",
        content=body.message,
        sources=[],
    )
    user_mid = UUID(str(um["id"]))

    text, cites = await rag_service.answer_sync(
        gemini_client=gemini,
        supabase_user=client,
        settings=settings,
        query_text=body.message,
        match_count=body.rag_top_k,
        only_in_effect=body.only_in_effect,
    )
    cites_models = [Citation.model_validate(x) for x in cites]

    assistant_row = await messages_repo.insert_message(
        client,
        thread_id=thread_id,
        user_id=user_id,
        role="assistant",
        content=text,
        sources=[x.model_dump() for x in cites_models],
    )
    assistant_mid = UUID(str(assistant_row["id"]))
    return ChatResponse(
        thread_id=thread_id,
        user_message_id=user_mid,
        assistant_message_id=assistant_mid,
        answer=text,
        sources=cites_models,
    )


async def stream_chat_sse(
    *,
    client: Client,
    gemini: genai.Client,
    settings: Settings,
    user_id: UUID,
    body: ChatRequest,
) -> AsyncIterator[str]:
    if body.thread_id is None:
        tid_row = await thread_service.create_thread(
            client,
            user_id=user_id,
            title=body.message[:120],
        )
        thread_id = UUID(str(tid_row["id"]))
    else:
        await thread_service.require_owned(client, thread_id=body.thread_id, user_id=user_id)
        thread_id = body.thread_id

    um = await messages_repo.insert_message(
        client,
        thread_id=thread_id,
        user_id=user_id,
        role="user",
        content=body.message,
        sources=[],
    )
    user_mid = str(um["id"])
    yield sse_data({"type": "thread", "thread_id": str(thread_id), "user_message_id": user_mid})

    buffer = ""
    sources_snapshot: list[dict] | None = None
    async for evt in rag_service.answer_stream_events(
        gemini_client=gemini,
        supabase_user=client,
        settings=settings,
        query_text=body.message,
        match_count=body.rag_top_k,
        only_in_effect=body.only_in_effect,
    ):
        if evt["type"] == "token":
            delta = str(evt.get("delta") or "")
            buffer += delta
            yield sse_data({"type": "token", "delta": delta})
        elif evt["type"] == "sources":
            sources_snapshot = list(evt.get("items") or [])
            yield sse_data({"type": "sources", "items": sources_snapshot})
        elif evt["type"] == "done":
            yield sse_data({"type": "done"})
        elif evt["type"] == "meta":
            yield sse_data({"type": "meta", "payload": evt})

    cites_models = [Citation.model_validate(x) for x in (sources_snapshot or [])]

    assistant_row = await messages_repo.insert_message(
        client,
        thread_id=thread_id,
        user_id=user_id,
        role="assistant",
        content=buffer,
        sources=[x.model_dump() for x in cites_models],
    )

    yield sse_data(
        {
            "type": "persisted",
            "assistant_message_id": str(assistant_row["id"]),
        }
    )
