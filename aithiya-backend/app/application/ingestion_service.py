from __future__ import annotations

from pathlib import Path
from uuid import UUID

from google import genai

from app.core.config import Settings
from app.core.exceptions import ValidationAppError
from app.infrastructure.db.repositories import documents_repo
from app.infrastructure.ingestion import chunker, pdf_loader
from app.infrastructure.ingestion.pipeline import ingest_pdf_file
from app.schemas.ingest import IngestionReport
from supabase import Client


async def ingest_uploaded_pdf(
    *,
    pdf_path: Path,
    gemini_client: genai.Client,
    service_client: Client,
    settings: Settings,
    admin_id: UUID,
    title_prefix: str,
    extra_metadata: dict,
) -> IngestionReport:
    summary = await ingest_pdf_file(
        pdf_path=pdf_path,
        gemini_client=gemini_client,
        service_client=service_client,
        settings=settings,
        admin_id=admin_id,
        title_prefix=title_prefix,
        extra_metadata=extra_metadata,
    )
    return IngestionReport.model_validate(summary)


async def resume_uploaded_pdf(
    *,
    pdf_path: Path,
    gemini_client: genai.Client,
    service_client: Client,
    settings: Settings,
    admin_id: UUID,
    title_prefix: str,
    extra_metadata: dict,
    ingest_id: UUID,
) -> IngestionReport:
    """Resume a previously-partial ingest by re-uploading the same PDF.

    We re-parse + re-chunk to recover the deterministic chunk list, query
    Supabase for which 1-based chunk indexes are already stored under this
    ingest_id, and pass the contiguous offset to the pipeline so it picks up
    from the first missing chunk.
    """
    markdown = await pdf_loader.pdf_path_to_markdown(pdf_path)
    max_chars = max(settings.chunk_max_tokens * 4, 256)
    overlap = settings.chunk_overlap_chars
    pieces = chunker.chunk_markdown(markdown, max_chars=max_chars, overlap=overlap)
    total_chunks = len(pieces)

    completed = await documents_repo.get_completed_chunk_indexes(
        service_client, ingest_id=ingest_id
    )
    if not completed:
        raise ValidationAppError(
            "No existing chunks found for this ingest_id; use POST /admin/ingest for a fresh upload",
        )

    max_completed = max(completed)
    if max_completed > total_chunks:
        raise ValidationAppError(
            "PDF mismatch: stored chunks exceed the chunk count produced by this PDF",
            details={"stored_max": max_completed, "pdf_total_chunks": total_chunks},
        )

    expected = set(range(1, max_completed + 1))
    if completed != expected:
        missing = sorted(expected - completed)
        raise ValidationAppError(
            "Non-contiguous completed chunks; cannot safely resume",
            details={"missing_chunk_indexes": missing[:20]},
        )

    if max_completed == total_chunks:
        summary = {
            "chunks_created": 0,
            "batches": 0,
            "duration_ms": 0,
            "title_prefix": title_prefix,
            "source_filename": pdf_path.name,
            "ingest_id": ingest_id,
            "total_chunks": total_chunks,
            "status": "complete",
            "next_chunk_index": None,
            "error": None,
        }
        return IngestionReport.model_validate(summary)

    summary = await ingest_pdf_file(
        pdf_path=pdf_path,
        gemini_client=gemini_client,
        service_client=service_client,
        settings=settings,
        admin_id=admin_id,
        title_prefix=title_prefix,
        extra_metadata=extra_metadata,
        ingest_id=ingest_id,
        start_index=max_completed,
    )
    return IngestionReport.model_validate(summary)
