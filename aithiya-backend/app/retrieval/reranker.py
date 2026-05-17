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


async def placeholder_rerank(*_a, **_k):
    raise NotImplementedError
