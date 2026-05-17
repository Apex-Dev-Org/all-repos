from __future__ import annotations

import re
from collections.abc import AsyncIterator, Sequence
from uuid import UUID

from google import genai

from app.application import rag_service, thread_service
from app.core.config import Settings
from app.domain.attachment import ChatAttachment
from app.infrastructure.ai.citation_renderer import render_for_user
from app.infrastructure.ai.generation import HistoryTurn
from app.infrastructure.ai.safety import preflight_check
from app.infrastructure.db.repositories import messages_repo
from app.schemas.chat import AttachmentMeta, ChatResponse, Citation
from app.utils.streaming import sse_data
from supabase import Client

_SOCIAL_WORDS = {"hi", "hello", "hey", "there", "aithiya", "aythiya"}
_SOCIAL_MESSAGES = {
    "hi",
    "hello",
    "hey",
    "hi there",
    "hello there",
    "hey there",
    "hi aithiya",
    "hello aithiya",
    "good morning",
    "good afternoon",
    "good evening",
    "thanks",
    "thank you",
    "thank you so much",
    "thanks a lot",
    "ok thanks",
    "okay thanks",
    "bye",
    "goodbye",
    "ආයුබෝවන්",
    "ස්තුතියි",
}
_THANKS_MESSAGES = {
    "thanks",
    "thank you",
    "thank you so much",
    "thanks a lot",
    "ok thanks",
    "okay thanks",
    "ස්තුතියි",
}


async def _load_history(
    *,
    client: Client,
    settings: Settings,
    thread_id: UUID | None,
    user_id: UUID,
) -> tuple[list[HistoryTurn], bool]:
    """Return (history, is_first_turn).

    History is in chronological order and capped at ``chat_history_turns``.
    A thread is treated as "first turn" when there are no prior persisted
    messages yet (the brand-new user message is inserted AFTER this call
    in the orchestrator).
    """
    if thread_id is None or settings.chat_history_turns <= 0:
        return [], True
    rows = await messages_repo.recent_messages(
        client,
        thread_id=thread_id,
        user_id=user_id,
        limit=settings.chat_history_turns,
    )
    history = [
        HistoryTurn(role=str(r.get("role") or "user"), content=str(r.get("content") or ""))
        for r in rows
    ]
    is_first_turn = len(history) == 0
    return history, is_first_turn


def _attachment_models(attachments: Sequence[ChatAttachment]) -> list[AttachmentMeta]:
    return [
        AttachmentMeta(filename=a.filename, mime_type=a.mime_type, size=len(a.data))
        for a in attachments
    ]


def _normalize_social_message(message: str) -> str:
    text = message.strip().lower()
    text = re.sub(r"[^\w\s'’]+", " ", text, flags=re.UNICODE)
    return re.sub(r"\s+", " ", text).strip()


def _simple_social_reply(
    message: str,
    attachments: Sequence[ChatAttachment],
) -> str | None:
    """Return a citation-free reply for small talk that does not need RAG."""
    if attachments:
        return None

    normalized = _normalize_social_message(message)
    if not normalized:
        return None

    words = normalized.split()
    is_greeting = normalized in _SOCIAL_MESSAGES or (
        0 < len(words) <= 3 and all(word in _SOCIAL_WORDS for word in words)
    )
    if not is_greeting:
        return None

    if normalized in _THANKS_MESSAGES:
        return "You're welcome. Ask me any Sri Lankan legal question when you're ready."
    if normalized in {"bye", "goodbye"}:
        return "Goodbye. I’ll be here when you need help understanding a Sri Lankan legal issue."
    return (
        "Hi, I’m Aithiya. Ask me a Sri Lankan legal question or attach a "
        "document, and I’ll help explain the relevant legal information."
    )


async def _resolve_thread(
    *,
    client: Client,
    user_id: UUID,
    thread_id: UUID | None,
    message: str,
) -> UUID:
    if thread_id is None:
        tid_row = await thread_service.create_thread(
            client,
            user_id=user_id,
            title=message[:120] or "New chat",
        )
        return UUID(str(tid_row["id"]))
    await thread_service.require_owned(client, thread_id=thread_id, user_id=user_id)
    return thread_id


async def _persist_user_message(
    *,
    client: Client,
    thread_id: UUID,
    user_id: UUID,
    message: str,
    attachments: Sequence[ChatAttachment],
) -> UUID:
    row = await messages_repo.insert_message(
        client,
        thread_id=thread_id,
        user_id=user_id,
        role="user",
        content=message,
        sources=rag_service.attachments_meta(attachments),
    )
    return UUID(str(row["id"]))


async def _persist_assistant_message(
    *,
    client: Client,
    thread_id: UUID,
    user_id: UUID,
    content: str,
    citations: Sequence[Citation],
) -> UUID:
    row = await messages_repo.insert_message(
        client,
        thread_id=thread_id,
        user_id=user_id,
        role="assistant",
        content=content,
        sources=rag_service.serialize_citations(citations),
    )
    return UUID(str(row["id"]))


async def complete_chat_exchange(
    *,
    client: Client,
    gemini: genai.Client,
    settings: Settings,
    user_id: UUID,
    message: str,
    thread_id: UUID | None,
    rag_top_k: int | None,
    only_in_effect: bool | None,
    attachments: Sequence[ChatAttachment],
) -> ChatResponse:
    thread_id = await _resolve_thread(
        client=client,
        user_id=user_id,
        thread_id=thread_id,
        message=message,
    )
    attachments = tuple(attachments)
    attachment_models = _attachment_models(attachments)

    history, is_first_turn = await _load_history(
        client=client,
        settings=settings,
        thread_id=thread_id,
        user_id=user_id,
    )

    user_mid = await _persist_user_message(
        client=client,
        thread_id=thread_id,
        user_id=user_id,
        message=message,
        attachments=attachments,
    )

    safety = preflight_check(message)
    if not safety.allow:
        refusal = safety.refusal or "I can't help with that."
        assistant_mid = await _persist_assistant_message(
            client=client,
            thread_id=thread_id,
            user_id=user_id,
            content=refusal,
            citations=[],
        )
        return ChatResponse(
            thread_id=thread_id,
            user_message_id=user_mid,
            assistant_message_id=assistant_mid,
            answer=refusal,
            sources=[],
            web_sources=[],
            attachments=attachment_models,
        )

    social_reply = _simple_social_reply(message, attachments)
    if social_reply:
        assistant_mid = await _persist_assistant_message(
            client=client,
            thread_id=thread_id,
            user_id=user_id,
            content=social_reply,
            citations=[],
        )
        return ChatResponse(
            thread_id=thread_id,
            user_message_id=user_mid,
            assistant_message_id=assistant_mid,
            answer=social_reply,
            sources=[],
            web_sources=[],
            attachments=attachment_models,
        )

    raw_text, citations, web_sources = await rag_service.answer_sync(
        gemini_client=gemini,
        supabase_user=client,
        settings=settings,
        query_text=message,
        match_count=rag_top_k,
        only_in_effect=only_in_effect,
        attachments=attachments,
        history=history,
        is_first_turn=is_first_turn,
    )
    final_text = render_for_user(raw_text, citations)

    assistant_mid = await _persist_assistant_message(
        client=client,
        thread_id=thread_id,
        user_id=user_id,
        content=final_text,
        citations=citations,
    )
    return ChatResponse(
        thread_id=thread_id,
        user_message_id=user_mid,
        assistant_message_id=assistant_mid,
        answer=final_text,
        sources=citations,
        web_sources=web_sources,
        attachments=attachment_models,
    )


async def stream_chat_sse(
    *,
    client: Client,
    gemini: genai.Client,
    settings: Settings,
    user_id: UUID,
    message: str,
    thread_id: UUID | None,
    rag_top_k: int | None,
    only_in_effect: bool | None,
    attachments: Sequence[ChatAttachment],
) -> AsyncIterator[str]:
    thread_id = await _resolve_thread(
        client=client,
        user_id=user_id,
        thread_id=thread_id,
        message=message,
    )
    attachments = tuple(attachments)
    attachment_models = _attachment_models(attachments)

    history, is_first_turn = await _load_history(
        client=client,
        settings=settings,
        thread_id=thread_id,
        user_id=user_id,
    )

    user_mid = await _persist_user_message(
        client=client,
        thread_id=thread_id,
        user_id=user_id,
        message=message,
        attachments=attachments,
    )

    yield sse_data(
        {
            "type": "thread",
            "thread_id": str(thread_id),
            "user_message_id": str(user_mid),
            "attachments": [am.model_dump() for am in attachment_models],
        }
    )

    safety = preflight_check(message)
    if not safety.allow:
        refusal = safety.refusal or "I can't help with that."
        yield sse_data({"type": "token", "delta": refusal})
        yield sse_data({"type": "sources", "items": []})
        yield sse_data({"type": "done"})
        assistant_row_id = await _persist_assistant_message(
            client=client,
            thread_id=thread_id,
            user_id=user_id,
            content=refusal,
            citations=[],
        )
        yield sse_data({"type": "final_text", "text": refusal})
        yield sse_data(
            {
                "type": "persisted",
                "assistant_message_id": str(assistant_row_id),
            }
        )
        return

    social_reply = _simple_social_reply(message, attachments)
    if social_reply:
        yield sse_data({"type": "token", "delta": social_reply})
        yield sse_data({"type": "sources", "items": []})
        yield sse_data({"type": "done"})
        assistant_row_id = await _persist_assistant_message(
            client=client,
            thread_id=thread_id,
            user_id=user_id,
            content=social_reply,
            citations=[],
        )
        yield sse_data({"type": "final_text", "text": social_reply})
        yield sse_data(
            {
                "type": "persisted",
                "assistant_message_id": str(assistant_row_id),
            }
        )
        return

    raw_buffer = ""
    citations: list[Citation] = []
    async for evt in rag_service.answer_stream_events(
        gemini_client=gemini,
        supabase_user=client,
        settings=settings,
        query_text=message,
        match_count=rag_top_k,
        only_in_effect=only_in_effect,
        attachments=attachments,
        history=history,
        is_first_turn=is_first_turn,
    ):
        etype = evt.get("type")
        if etype == "token":
            delta = str(evt.get("delta") or "")
            raw_buffer += delta
            yield sse_data({"type": "token", "delta": delta})
        elif etype == "sources":
            items = list(evt.get("items") or [])
            citations = [Citation.model_validate(x) for x in items]
            yield sse_data({"type": "sources", "items": items})
        elif etype == "done":
            yield sse_data({"type": "done"})
        elif etype == "meta":
            yield sse_data({"type": "meta", "payload": evt})

    final_text = render_for_user(raw_buffer, citations)
    yield sse_data({"type": "final_text", "text": final_text})

    assistant_row_id = await _persist_assistant_message(
        client=client,
        thread_id=thread_id,
        user_id=user_id,
        content=final_text,
        citations=citations,
    )
    yield sse_data(
        {
            "type": "persisted",
            "assistant_message_id": str(assistant_row_id),
        }
    )


__all__ = ["complete_chat_exchange", "stream_chat_sse"]
