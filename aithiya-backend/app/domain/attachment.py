from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True, frozen=True)
class ChatAttachment:
    filename: str
    mime_type: str
    data: bytes
