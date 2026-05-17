from __future__ import annotations

from pathlib import Path
from uuid import UUID

from google import genai

from app.core.config import Settings
from app.ingestion.pipeline import ingest_pdf_file
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
