from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from uuid import UUID


@dataclass(slots=True)
class RetrievedChunk:
    doc_id: UUID
    title: str
    content: str
    metadata: dict[str, Any]
    similarity: float
