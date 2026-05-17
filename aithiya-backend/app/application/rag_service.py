from __future__ import annotations

from collections.abc import AsyncIterator, Sequence
from typing import Any

from google import genai

from app.core.config import Settings
from app.domain.attachment import ChatAttachment
from app.domain.citation import extract_citation_parts
from app.domain.retrieval import RetrievedChunk
from app.infrastructure.ai.embeddings import embed_query
from app.infrastructure.ai.generation import (
    HistoryTurn,
    generate_text,
    generate_text_stream,
)
from app.infrastructure.ai.grounding import (
    build_search_tool,
    extract_web_sources,
    should_enable_web_search,
)
from app.infrastructure.ai.prompts.rag_prompt import (
    build_system_instruction,
    build_user_prompt,
)
from app.infrastructure.retrieval.vector_search import match_documents
from app.schemas.chat import Citation, WebSource
from supabase import Client


_EXCERPT_MAX_CHARS = 500


def _excerpt(content: str) -> str:
    if len(content) <= _EXCERPT_MAX_CHARS:
        return content
    return content[:_EXCERPT_MAX_CHARS] + "..."


def citations_from_chunks(chunks: Sequence[RetrievedChunk]) -> list[Citation]:
    """Build Citation objects from retrieved chunks.

    The ``index`` is what the LLM is told to cite (``[1]``, ``[2]`` ...).
    Internal ``doc_id`` is kept on the model so the frontend can resolve
    things like "open the original document" — but the LLM is never
    shown it and the renderer strips any leak.
    """
    out: list[Citation] = []
    for i, ch in enumerate(chunks, start=1):
        parts = extract_citation_parts(ch.metadata, title=ch.title)
        out.append(
            Citation(
                index=i,
                doc_id=ch.doc_id,
                act_name=parts.act_name,
                act_no=parts.act_no,
                section=parts.section,
                article=parts.article,
                regulation_name=parts.regulation_name,
                chapter=parts.chapter,
                year=parts.year,
                jurisdiction=parts.jurisdiction,
                title=ch.title or None,
                citation_label=parts.long_label(fallback_title=ch.title),
                compact_label=parts.compact_label(fallback_title=ch.title),
                similarity=ch.similarity,
                content_excerpt=_excerpt(ch.content),
            )
        )
    return out


def _maybe_tools(query_text: str, settings: Settings):
    if not should_enable_web_search(query_text, settings):
        return None
    return [build_search_tool()]


async def answer_sync(
    *,
    gemini_client: genai.Client,
    supabase_user: Client,
    settings: Settings,
    query_text: str,
    match_count: int | None,
    only_in_effect: bool | None,
    attachments: Sequence[ChatAttachment] | None = None,
    history: Sequence[HistoryTurn] | None = None,
    is_first_turn: bool = True,
) -> tuple[str, list[Citation], list[WebSource]]:
    embedding = await embed_query(gemini_client, settings, query_text)
    chunks = await match_documents(
        supabase_user,
        settings,
        embedding,
        match_count=match_count,
        only_in_effect=only_in_effect,
    )
    citations = citations_from_chunks(chunks)
    system = build_system_instruction()
    att = tuple(attachments or ())
    user_prompt = build_user_prompt(
        query_text,
        chunks,
        citations,
        attachments=att,
        is_first_turn=is_first_turn,
    )
    tools = _maybe_tools(query_text, settings)
    text, resp = await generate_text(
        gemini_client,
        settings,
        system=system,
        user=user_prompt,
        attachments=att,
        history=history,
        tools=tools,
    )
    web_sources = extract_web_sources(resp) if tools else []
    return text, citations, web_sources


async def answer_stream_events(
    *,
    gemini_client: genai.Client,
    supabase_user: Client,
    settings: Settings,
    query_text: str,
    match_count: int | None,
    only_in_effect: bool | None,
    attachments: Sequence[ChatAttachment] | None = None,
    history: Sequence[HistoryTurn] | None = None,
    is_first_turn: bool = True,
) -> AsyncIterator[dict[str, Any]]:
    embedding = await embed_query(gemini_client, settings, query_text)
    chunks = await match_documents(
        supabase_user,
        settings,
        embedding,
        match_count=match_count,
        only_in_effect=only_in_effect,
    )
    citations = citations_from_chunks(chunks)
    yield {"type": "meta", "retrieved": len(chunks)}
    yield {
        "type": "sources",
        "items": [c.model_dump(mode="json") for c in citations],
    }

    system = build_system_instruction()
    att = tuple(attachments or ())
    user_prompt = build_user_prompt(
        query_text,
        chunks,
        citations,
        attachments=att,
        is_first_turn=is_first_turn,
    )
    tools = _maybe_tools(query_text, settings)
    async for piece in generate_text_stream(
        gemini_client,
        settings,
        system=system,
        user=user_prompt,
        attachments=att,
        history=history,
        tools=tools,
    ):
        if piece:
            yield {"type": "token", "delta": piece}
    yield {"type": "done"}


def serialize_citations(citations: Sequence[Citation]) -> list[dict[str, Any]]:
    """Persisted shape for the ``chat_messages.sources`` jsonb column."""
    return [c.model_dump(mode="json") for c in citations]


def attachments_meta(attachments: Sequence[ChatAttachment]) -> list[dict[str, Any]]:
    """Persisted shape for user-message attachments."""
    return [
        {
            "kind": "attachment",
            "filename": a.filename,
            "mime_type": a.mime_type,
            "size": len(a.data),
        }
        for a in attachments
    ]


__all__ = [
    "HistoryTurn",
    "answer_stream_events",
    "answer_sync",
    "attachments_meta",
    "citations_from_chunks",
    "serialize_citations",
]
