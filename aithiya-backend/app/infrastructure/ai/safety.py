"""Cheap preflight refusal for clearly disallowed queries.

The system prompt + Gemini's own safety classifiers handle the bulk of
unsafe-content judgement. This module exists only to short-circuit the
most egregiously disallowed requests before we spend tokens on them
(e.g. someone literally asking how to forge a court summons).

Patterns and the refusal copy live in editable files under
``prompts/templates/safety/`` so non-developers can tune them without
touching code:

- ``patterns.json`` — list of ``{"category", "pattern", "ignore_case"?}``
  entries compiled as ``re.Pattern``.
- ``refusal.md`` — user-facing refusal text returned when any pattern
  matches.

Keep the patterns short, conservative, and English-only. False
positives here block users entirely, so err on the side of letting the
model decide for anything ambiguous.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

_SAFETY_DIR = Path(__file__).resolve().parent / "prompts" / "templates" / "safety"
_PATTERNS_PATH = _SAFETY_DIR / "patterns.json"
_REFUSAL_PATH = _SAFETY_DIR / "refusal.md"

_FALLBACK_REFUSAL = (
    "I can't help with that. If you have a legitimate legal question — for "
    "example about your rights, the steps in a lawful process, or where to "
    "find official help — please rephrase and I'll do my best."
)


@dataclass(slots=True, frozen=True)
class SafetyDecision:
    allow: bool
    category: str | None = None
    refusal: str | None = None


def _compile_entry(entry: dict[str, object]) -> tuple[str, re.Pattern[str]] | None:
    category = str(entry.get("category") or "").strip()
    pattern = str(entry.get("pattern") or "").strip()
    if not category or not pattern:
        return None
    ignore_case = entry.get("ignore_case", True)
    flags = re.IGNORECASE if ignore_case else 0
    try:
        return category, re.compile(pattern, flags)
    except re.error:
        return None


@lru_cache(maxsize=1)
def _load_patterns() -> tuple[tuple[str, re.Pattern[str]], ...]:
    if not _PATTERNS_PATH.exists():
        return ()
    try:
        payload = json.loads(_PATTERNS_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ()
    raw = payload.get("patterns") if isinstance(payload, dict) else None
    if not isinstance(raw, list):
        return ()
    compiled: list[tuple[str, re.Pattern[str]]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        item = _compile_entry(entry)
        if item is not None:
            compiled.append(item)
    return tuple(compiled)


@lru_cache(maxsize=1)
def _load_refusal() -> str:
    if not _REFUSAL_PATH.exists():
        return _FALLBACK_REFUSAL
    try:
        text = _REFUSAL_PATH.read_text(encoding="utf-8").strip()
    except OSError:
        return _FALLBACK_REFUSAL
    return text or _FALLBACK_REFUSAL


def preflight_check(query: str) -> SafetyDecision:
    """Return a refusal when ``query`` clearly asks for disallowed content."""
    if not query:
        return SafetyDecision(allow=True)
    text = query.strip()
    if not text:
        return SafetyDecision(allow=True)
    for category, pat in _load_patterns():
        if pat.search(text):
            return SafetyDecision(
                allow=False,
                category=category,
                refusal=_load_refusal(),
            )
    return SafetyDecision(allow=True)


def reload_safety() -> None:
    """Drop cached patterns and refusal copy so admins can hot-edit them."""
    _load_patterns.cache_clear()
    _load_refusal.cache_clear()


__all__ = ["SafetyDecision", "preflight_check", "reload_safety"]
