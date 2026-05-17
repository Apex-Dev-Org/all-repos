from __future__ import annotations

import time
from pathlib import Path
from typing import Any
from uuid import UUID

from google import genai

from app.ai.embeddings import embed_batch
from app.core.config import Settings
from app.db.repositories import documents_repo
from app.ingestion import batcher, chunker, pdf_loader
from supabase import Client


async def ingest_pdf_file(
    *,
    pdf_path: Path,
    gemini_client: genai.Client,
    service_client: Client,
    settings: Settings,
    admin_id: UUID,
    title_prefix: str,
    extra_metadata: dict[str, Any],
) -> dict[str, Any]:
    started = time.perf_counter()
    markdown = await pdf_loader.pdf_path_to_markdown(pdf_path)
    max_chars = max(settings.chunk_max_tokens * 4, 256)
    overlap = settings.chunk_overlap_chars
    pieces = chunker.chunk_markdown(markdown, max_chars=max_chars, overlap=overlap)
    if not pieces:
        ms = int((time.perf_counter() - started) * 1000)
        return {
            "chunks_created": 0,
            "batches": 0,
            "duration_ms": ms,
            "title_prefix": title_prefix,
            "source_filename": pdf_path.name,
        }

    rows_accum: list[dict[str, Any]] = []
    batch_count = 0
    idx = 0
    for batch_texts in batcher.batched(pieces, settings.embed_batch_size):
        batch_count += 1
        vectors = await embed_batch(gemini_client, settings, list(batch_texts))
        for text, vec in zip(batch_texts, vectors, strict=True):
            idx += 1
            meta = {
                **extra_metadata,
                "chunk_index": idx,
                "source_file": pdf_path.name,
            }
            rows_accum.append(
                {
                    "title": f"{title_prefix} · chunk {idx}",
                    "content": text,
                    "metadata": meta,
                    "embedding": vec,
                    "is_in_effect": True,
                    "created_by": str(admin_id),
                }
            )

    await documents_repo.bulk_insert_documents(service_client, rows_accum)
    ms = int((time.perf_counter() - started) * 1000)
    return {
        "chunks_created": len(rows_accum),
        "batches": batch_count,
        "duration_ms": ms,
        "title_prefix": title_prefix,
        "source_filename": pdf_path.name,
    }
