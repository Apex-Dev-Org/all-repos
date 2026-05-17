"""Post-process Gemini output before persisting / returning to the user.

The model is instructed to cite using ``[1]``, ``[2]``, ... markers that
map 1:1 onto the numbered ``CONTEXT`` blocks the backend constructed.
On the way out we:

1. Strip any defensively-leaked internal identifiers (UUID-style citations
   like ``[doc:2e7405d4-d74a-4260-ab2e-153fb63ab031]``) — the prompt
   forbids them, but we never want a single misbehaving response to
   expose an internal id, so this is a belt-and-braces safeguard.
2. Replace ``[N]`` markers with a short human-readable label drawn from
   the resolved ``Citation`` list (e.g. ``[Penal Code, s. 302]``), and
   drop unknown numbers that the model may have hallucinated.

Both functions are pure string transforms; no I/O.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from app.core.logging import log
from app.schemas.chat import Citation

_UUID_RE = (
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)
_LEAKED_ID_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(rf"\[\s*doc\s*[:=]\s*{_UUID_RE}\s*\]", re.IGNORECASE),
    re.compile(rf"\(\s*doc\s*[:=]\s*{_UUID_RE}\s*\)", re.IGNORECASE),
    re.compile(rf"\bdoc\s*[:=]\s*{_UUID_RE}\b", re.IGNORECASE),
    re.compile(rf"\[\s*id\s*[:=]\s*{_UUID_RE}\s*\]", re.IGNORECASE),
    re.compile(rf"\[\s*{_UUID_RE}\s*\]"),
)

_NUMERIC_MARKER_RE = re.compile(r"\[(\d{1,3})\]")
_NUMERIC_GROUP_RE = re.compile(r"\[(\d{1,3}(?:\s*,\s*\d{1,3})+)\]")


def strip_uuid_citations(text: str) -> str:
    """Defensively remove leaked internal identifiers from model output."""
    if not text:
        return text
    cleaned = text
    for pat in _LEAKED_ID_PATTERNS:
        cleaned = pat.sub("", cleaned)
    cleaned = re.sub(r"[ \t]{2,}", " ", cleaned)
    cleaned = re.sub(r"\s+([,.;:!?])", r"\1", cleaned)
    return cleaned


def substitute_inline_markers(
    text: str,
    citations: Iterable[Citation],
) -> str:
    """Replace ``[N]`` and ``[N, M]`` markers with compact labels.

    Markers whose number does not match any citation are removed and a
    warning is logged (the model invented an index).
    """
    if not text:
        return text
    by_index: dict[int, Citation] = {c.index: c for c in citations}
    if not by_index:
        cleaned = _NUMERIC_MARKER_RE.sub("", _NUMERIC_GROUP_RE.sub("", text))
        cleaned = re.sub(r"[ \t]{2,}", " ", cleaned)
        cleaned = re.sub(r"\s+([,.;:!?])", r"\1", cleaned)
        return cleaned

    logger = log()

    def _label(n: int) -> str | None:
        c = by_index.get(n)
        if c is None:
            return None
        return c.compact_label

    def _replace_group(match: re.Match[str]) -> str:
        raw = match.group(1)
        nums = [int(x.strip()) for x in raw.split(",")]
        labels: list[str] = []
        for n in nums:
            lab = _label(n)
            if lab is None:
                logger.warning("citation_marker_unknown", marker=n)
                continue
            labels.append(lab)
        if not labels:
            return ""
        return "[" + "; ".join(labels) + "]"

    def _replace_single(match: re.Match[str]) -> str:
        n = int(match.group(1))
        lab = _label(n)
        if lab is None:
            logger.warning("citation_marker_unknown", marker=n)
            return ""
        return f"[{lab}]"

    out = _NUMERIC_GROUP_RE.sub(_replace_group, text)
    out = _NUMERIC_MARKER_RE.sub(_replace_single, out)
    out = re.sub(r"[ \t]{2,}", " ", out)
    out = re.sub(r"\s+([,.;:!?])", r"\1", out)
    return out


def render_for_user(text: str, citations: Iterable[Citation]) -> str:
    """Apply both safeguards in order."""
    return substitute_inline_markers(strip_uuid_citations(text), citations)
