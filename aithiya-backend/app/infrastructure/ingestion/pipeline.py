from __future__ import annotations

import asyncio
import time
import uuid
from pathlib import Path
from typing import Any
from uuid import UUID

from google import genai

from app.core.config import Settings
from app.core.exceptions import EmbedQuotaError
from app.core.logging import log
from app.infrastructure.ai.embeddings import embed_batch_with_quota_handling
from app.infrastructure.db.repositories import documents_repo
from app.infrastructure.ingestion import batcher, chunker, pdf_loader
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
    ingest_id: UUID | None = None,
    start_index: int = 0,
) -> dict[str, Any]:
    """Parse, chunk, embed and store a PDF, batch by batch.

    Each batch is embedded then saved to Supabase immediately so a mid-run
    quota exhaustion does not lose work. On EmbedQuotaError we stop the loop
    and return a partial report containing `ingest_id` and the next 1-based
    chunk index to resume from.

    `start_index` is a 0-based slice offset into the chunk list; pass the
    count of already-ingested chunks when resuming.
    """
    started = time.perf_counter()
    ingest_id = ingest_id or uuid.uuid4()

    logger = log()
    logger.info(
        "ingest_start",
        ingest_id=str(ingest_id),
        source_file=pdf_path.name,
        start_index=start_index,
    )

    parse_started = time.perf_counter()
    markdown = await pdf_loader.pdf_path_to_markdown(pdf_path)
    parse_ms = int((time.perf_counter() - parse_started) * 1000)
    logger.info(
        "pdf_parsed",
        ingest_id=str(ingest_id),
        markdown_chars=len(markdown),
        ms=parse_ms,
    )

    max_chars = max(settings.chunk_max_tokens * 4, 256)
    overlap = settings.chunk_overlap_chars
    pieces = chunker.chunk_markdown(markdown, max_chars=max_chars, overlap=overlap)
    total_chunks = len(pieces)
    logger.info(
        "chunks_ready",
        ingest_id=str(ingest_id),
        count=total_chunks,
        start_index=start_index,
    )

    if total_chunks == 0:
        ms = int((time.perf_counter() - started) * 1000)
        logger.info(
            "ingest_done",
            ingest_id=str(ingest_id),
            status="complete",
            chunks_inserted=0,
            total_ms=ms,
        )
        return {
            "chunks_created": 0,
            "batches": 0,
            "duration_ms": ms,
            "title_prefix": title_prefix,
            "source_filename": pdf_path.name,
            "ingest_id": ingest_id,
            "total_chunks": 0,
            "status": "complete",
            "next_chunk_index": None,
            "error": None,
        }

    if start_index >= total_chunks:
        ms = int((time.perf_counter() - started) * 1000)
        logger.info(
            "ingest_done",
            ingest_id=str(ingest_id),
            status="complete",
            chunks_inserted=0,
            total_ms=ms,
            note="nothing_to_do",
        )
        return {
            "chunks_created": 0,
            "batches": 0,
            "duration_ms": ms,
            "title_prefix": title_prefix,
            "source_filename": pdf_path.name,
            "ingest_id": ingest_id,
            "total_chunks": total_chunks,
            "status": "complete",
            "next_chunk_index": None,
            "error": None,
        }

    remaining = pieces[start_index:]
    batch_size = settings.embed_batch_size
    total_batches = (len(remaining) + batch_size - 1) // batch_size

    chunks_inserted_this_call = 0
    batches_done_this_call = 0
    idx = start_index
    next_chunk_index: int | None = None
    error_msg: str | None = None
    status = "complete"

    try:
        for batch_no, batch_texts in enumerate(
            batcher.batched(remaining, batch_size), start=1
        ):
            batch_started = time.perf_counter()
            logger.info(
                "batch_start",
                ingest_id=str(ingest_id),
                batch=batch_no,
                of=total_batches,
                size=len(batch_texts),
            )

            if batches_done_this_call > 0 and settings.embed_batch_delay_s > 0:
                await asyncio.sleep(settings.embed_batch_delay_s)

            vectors = await embed_batch_with_quota_handling(
                gemini_client, settings, list(batch_texts)
            )

            rows: list[dict[str, Any]] = []
            for text, vec in zip(batch_texts, vectors, strict=True):
                idx += 1
                meta = {
                    **extra_metadata,
                    "ingest_id": str(ingest_id),
                    "chunk_index": idx,
                    "total_chunks": total_chunks,
                    "source_file": pdf_path.name,
                }
                rows.append(
                    {
                        "title": f"{title_prefix} \u00b7 chunk {idx}",
                        "content": text,
                        "metadata": meta,
                        "embedding": vec,
                        "is_in_effect": True,
                        "created_by": str(admin_id),
                    }
                )

            await documents_repo.bulk_insert_documents(service_client, rows)
            chunks_inserted_this_call += len(rows)
            batches_done_this_call += 1

            batch_ms = int((time.perf_counter() - batch_started) * 1000)
            cumulative_ms = int((time.perf_counter() - started) * 1000)
            logger.info(
                "batch_done",
                ingest_id=str(ingest_id),
                batch=batch_no,
                of=total_batches,
                ms=batch_ms,
                cumulative_ms=cumulative_ms,
                inserted_so_far=chunks_inserted_this_call,
                last_chunk_index=idx,
            )
    except EmbedQuotaError as exc:
        status = "partial"
        next_chunk_index = idx + 1
        error_msg = str(exc)
        logger.warning(
            "quota_exhausted",
            ingest_id=str(ingest_id),
            at_batch=batches_done_this_call + 1,
            chunks_inserted=chunks_inserted_this_call,
            next_chunk_index=next_chunk_index,
        )

    total_ms = int((time.perf_counter() - started) * 1000)
    logger.info(
        "ingest_done",
        ingest_id=str(ingest_id),
        status=status,
        chunks_inserted=chunks_inserted_this_call,
        total_ms=total_ms,
    )

    return {
        "chunks_created": chunks_inserted_this_call,
        "batches": batches_done_this_call,
        "duration_ms": total_ms,
        "title_prefix": title_prefix,
        "source_filename": pdf_path.name,
        "ingest_id": ingest_id,
        "total_chunks": total_chunks,
        "status": status,
        "next_chunk_index": next_chunk_index,
        "error": error_msg,
    }
