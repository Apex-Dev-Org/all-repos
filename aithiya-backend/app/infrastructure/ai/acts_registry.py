"""Lookup table that turns internal ingest codes into Act metadata.

When a PDF is ingested via ``scripts/ingest_local.py`` the chunk title is
built as ``"{title_prefix} \u00b7 chunk N"``. For most of our seed data the
``title_prefix`` is a short internal code (e.g. ``CIVIL-PROCEDURE-CODE``)
because admins do not want to retype the full Act name for every PDF.

This registry maps those internal codes to structured citation fields
(``act_name``, ``act_no``, ``year``, ``jurisdiction``) so the citation
builder can render user-facing labels like
``Civil Procedure Code, Act No. 2 of 1889`` even when the underlying
chunk metadata only contains the source filename.

The registry is loaded from ``prompts/data/acts.json`` at import time,
cached, and normalized so lookups are case-insensitive and tolerant of
hyphen/underscore/space variations and ``" \u00b7 chunk N"`` suffixes.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

_REGISTRY_PATH = Path(__file__).resolve().parent / "prompts" / "data" / "acts.json"
_CHUNK_SUFFIX_RE = re.compile(r"\s*\u00b7\s*chunk\s*\d+\s*$", re.IGNORECASE)
_NORMALIZE_RE = re.compile(r"[\s_]+")


@dataclass(slots=True, frozen=True)
class ActRecord:
    """Normalized record describing a single Sri Lankan legal act."""

    code: str
    act_name: str
    act_no: str | None = None
    year: str | None = None
    jurisdiction: str | None = None


def _normalize_key(raw: str) -> str:
    if not raw:
        return ""
    cleaned = _CHUNK_SUFFIX_RE.sub("", raw)
    cleaned = cleaned.strip().strip("-\u2013\u2014").strip()
    cleaned = _NORMALIZE_RE.sub("-", cleaned)
    return cleaned.upper()


def _coerce_record(raw: dict[str, Any]) -> ActRecord | None:
    code = str(raw.get("code") or "").strip()
    name = str(raw.get("act_name") or "").strip()
    if not code or not name:
        return None
    return ActRecord(
        code=code,
        act_name=name,
        act_no=(str(raw["act_no"]).strip() if raw.get("act_no") else None),
        year=(str(raw["year"]).strip() if raw.get("year") else None),
        jurisdiction=(
            str(raw["jurisdiction"]).strip() if raw.get("jurisdiction") else None
        ),
    )


def _build_index(payload: dict[str, Any]) -> dict[str, ActRecord]:
    index: dict[str, ActRecord] = {}
    for entry in payload.get("acts", []) or []:
        if not isinstance(entry, dict):
            continue
        record = _coerce_record(entry)
        if record is None:
            continue
        keys: list[str] = [record.code]
        for alias in entry.get("aliases", []) or []:
            if isinstance(alias, str) and alias.strip():
                keys.append(alias)
        for key in keys:
            norm = _normalize_key(key)
            if norm and norm not in index:
                index[norm] = record
    return index


@lru_cache(maxsize=1)
def _load_index() -> dict[str, ActRecord]:
    if not _REGISTRY_PATH.exists():
        return {}
    try:
        payload = json.loads(_REGISTRY_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(payload, dict):
        return {}
    return _build_index(payload)


def lookup_act(title_or_code: str | None) -> ActRecord | None:
    """Resolve a chunk title or ingest code to a registered ``ActRecord``.

    Lookup is case-insensitive, ignores the ``" \u00b7 chunk N"`` suffix
    appended at ingest time, and treats whitespace/underscores as
    hyphens (so ``Civil_Procedure_Code`` and ``civil procedure code``
    both resolve to the ``CIVIL-PROCEDURE-CODE`` entry).
    """
    if not title_or_code:
        return None
    key = _normalize_key(title_or_code)
    if not key:
        return None
    return _load_index().get(key)


def reload_registry() -> None:
    """Drop the cached index so a subsequent call re-reads ``acts.json``.

    Useful when admins edit the JSON file on a running server.
    """
    _load_index.cache_clear()


__all__ = ["ActRecord", "lookup_act", "reload_registry"]
