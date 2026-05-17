from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

from google import genai

from app.ai.embeddings import embed_query
from app.ai.generation import generate_text, generate_text_stream
from app.ai.language import heuristic_language
from app.ai.prompts.rag_prompt import build_system_instruction, build_user_prompt
from app.core.config import Settings
from app.retrieval.reranker import RetrievedChunk
from app.retrieval.vector_search import match_documents
from supabase import Client


def citations_from_chunks(chunks: list[RetrievedChunk]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for ch in chunks:
        excerpt = ch.content[:500] + ("..." if len(ch.content) > 500 else "")
        out.append(
            {
                "doc_id": str(ch.doc_id),
                "title": ch.title,
                "similarity": ch.similarity,
                "content_excerpt": excerpt,
            }
        )
    return out


async def answer_sync(
    *,
    gemini_client: genai.Client,
    supabase_user: Client,
    settings: Settings,
    query_text: str,
    match_count: int | None,
    only_in_effect: bool | None,
) -> tuple[str, list[dict[str, Any]]]:
    lang = heuristic_language(query_text)
    embedding = await embed_query(gemini_client, settings, query_text)
    chunks = await match_documents(
        supabase_user,
        settings,
        embedding,
        match_count=match_count,
        only_in_effect=only_in_effect,
    )
    system = build_system_instruction(lang)
    user_prompt = build_user_prompt(query_text, chunks, lang)
    text = await generate_text(gemini_client, settings, system=system, user=user_prompt)
    return text, citations_from_chunks(chunks)


async def answer_stream_events(
    *,
    gemini_client: genai.Client,
    supabase_user: Client,
    settings: Settings,
    query_text: str,
    match_count: int | None,
    only_in_effect: bool | None,
) -> AsyncIterator[dict[str, Any]]:
    lang = heuristic_language(query_text)
    embedding = await embed_query(gemini_client, settings, query_text)
    chunks = await match_documents(
        supabase_user,
        settings,
        embedding,
        match_count=match_count,
        only_in_effect=only_in_effect,
    )
    yield {"type": "meta", "language": lang.value, "retrieved": len(chunks)}
    system = build_system_instruction(lang)
    user_prompt = build_user_prompt(query_text, chunks, lang)
    async for piece in generate_text_stream(
        gemini_client, settings, system=system, user=user_prompt
    ):
        if piece:
            yield {"type": "token", "delta": piece}
    yield {"type": "sources", "items": citations_from_chunks(chunks)}
    yield {"type": "done"}
