from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID


@dataclass(slots=True)
class CurrentUser:
    id: UUID
    email: str | None
