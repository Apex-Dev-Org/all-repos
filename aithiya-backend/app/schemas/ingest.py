from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class IngestionReport(BaseModel):
    source_filename: str
    chunks_created: int
    batches: int
    duration_ms: int
    title_prefix: str = Field(description="applied to each chunk title prefix")
    ingest_id: UUID
    total_chunks: int
    status: Literal["complete", "partial"] = "complete"
    next_chunk_index: int | None = None
    error: str | None = None
