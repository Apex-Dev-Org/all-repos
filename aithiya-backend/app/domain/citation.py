"""Build human-readable legal citation labels from chunk metadata.

The vector store keeps a free-form ``metadata`` jsonb on each
``legal_documents`` row (populated by the admin at ingest time via
``metadata_json``). We extract a small set of structured fields here so
that responses can cite laws by Act name + section instead of by opaque
UUIDs.

When chunk metadata is sparse (older ingests only carried
``source_file`` and ``chunk_index``), we additionally consult the act
registry shipped under ``infrastructure/ai/prompts/data/acts.json`` so
the chunk's internal title prefix (e.g. ``CIVIL-PROCEDURE-CODE``) is
resolved to a proper Act name and Act No. Metadata wins over the
registry for every field — the registry only fills holes.

Keep this module dependency-light; it is consumed by both the prompt
builder and the response post-processor.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.infrastructure.ai.acts_registry import ActRecord, lookup_act

_ACT_NAME_KEYS = ("act_name", "act", "statute", "law_name", "ordinance_name")
_ACT_NO_KEYS = ("act_no", "act_number", "no", "number")
_SECTION_KEYS = ("section", "sec", "s", "section_number")
_ARTICLE_KEYS = ("article", "art", "article_number")
_REGULATION_KEYS = ("regulation_name", "regulation", "reg_name")
_YEAR_KEYS = ("year", "act_year", "enacted_year")
_JURISDICTION_KEYS = ("jurisdiction", "country")
_CHAPTER_KEYS = ("chapter", "chapter_name", "chapter_number")


def _first(meta: dict[str, Any], keys: tuple[str, ...]) -> str | None:
    for k in keys:
        v = meta.get(k)
        if v is None:
            continue
        s = str(v).strip()
        if s:
            return s
    return None


@dataclass(slots=True, frozen=True)
class CitationParts:
    """Normalized citation fields extracted from chunk metadata."""

    act_name: str | None
    act_no: str | None
    section: str | None
    article: str | None
    regulation_name: str | None
    chapter: str | None
    year: str | None
    jurisdiction: str | None

    def long_label(self, *, fallback_title: str | None = None) -> str:
        """Full citation, e.g. ``Penal Code No. 2 of 1883, s. 302``.

        Falls back to ``fallback_title`` (typically the chunk title) when
        not enough structured fields are present to compose a meaningful
        label, and finally to ``"Untitled source"``.
        """
        parts: list[str] = []
        if self.act_name:
            base = self.act_name
            if self.act_no:
                base = f"{base} No. {self.act_no}"
            elif self.year:
                base = f"{base} ({self.year})"
            parts.append(base)
        elif self.regulation_name:
            parts.append(self.regulation_name)

        locator = self._locator()
        if locator:
            parts.append(locator)

        if not parts:
            if fallback_title:
                cleaned = _strip_chunk_suffix(fallback_title)
                return cleaned or "Untitled source"
            return "Untitled source"
        return ", ".join(parts)

    def compact_label(self, *, fallback_title: str | None = None) -> str:
        """Short citation suitable for inline rendering inside answers.

        Strips the ``Year`` parenthesis and keeps the Act + locator.
        Examples: ``Penal Code, s. 302``, ``Constitution, Art. 12(1)``.
        """
        if self.act_name:
            base = self.act_name
        elif self.regulation_name:
            base = self.regulation_name
        else:
            if fallback_title:
                cleaned = _strip_chunk_suffix(fallback_title)
                return cleaned or "Untitled source"
            return "Untitled source"

        locator = self._locator()
        return f"{base}, {locator}" if locator else base

    def _locator(self) -> str | None:
        if self.section:
            return f"s. {self.section}"
        if self.article:
            return f"Art. {self.article}"
        if self.chapter:
            return f"ch. {self.chapter}"
        return None


def _merge_with_registry(
    parts: CitationParts,
    record: ActRecord | None,
) -> CitationParts:
    """Fill missing structured fields from a registered Act record.

    Metadata always wins — the registry only supplies values that the
    metadata did not set. This keeps existing rich ingests deterministic
    while letting code-only ingests render a friendly Act name.
    """
    if record is None:
        return parts
    return CitationParts(
        act_name=parts.act_name or record.act_name,
        act_no=parts.act_no or record.act_no,
        section=parts.section,
        article=parts.article,
        regulation_name=parts.regulation_name,
        chapter=parts.chapter,
        year=parts.year or record.year,
        jurisdiction=parts.jurisdiction or record.jurisdiction,
    )


def extract_citation_parts(
    metadata: dict[str, Any] | None,
    *,
    title: str | None = None,
) -> CitationParts:
    """Pull structured citation fields out of a free-form metadata dict.

    When ``title`` is provided and metadata is missing an ``act_name``
    (or ``regulation_name``), the title is looked up in the act registry
    and any matching fields are merged in (metadata still wins for any
    field it explicitly set).
    """
    meta = metadata or {}
    parts = CitationParts(
        act_name=_first(meta, _ACT_NAME_KEYS),
        act_no=_first(meta, _ACT_NO_KEYS),
        section=_first(meta, _SECTION_KEYS),
        article=_first(meta, _ARTICLE_KEYS),
        regulation_name=_first(meta, _REGULATION_KEYS),
        chapter=_first(meta, _CHAPTER_KEYS),
        year=_first(meta, _YEAR_KEYS),
        jurisdiction=_first(meta, _JURISDICTION_KEYS),
    )
    if parts.act_name or parts.regulation_name:
        return parts
    record = lookup_act(title) if title else None
    return _merge_with_registry(parts, record)


def build_citation_label(
    metadata: dict[str, Any] | None,
    *,
    fallback_title: str | None = None,
) -> str:
    """Convenience: long-form citation label from metadata + fallback title."""
    return extract_citation_parts(metadata, title=fallback_title).long_label(
        fallback_title=fallback_title
    )


def build_compact_citation_label(
    metadata: dict[str, Any] | None,
    *,
    fallback_title: str | None = None,
) -> str:
    """Convenience: short inline label from metadata + fallback title."""
    return extract_citation_parts(metadata, title=fallback_title).compact_label(
        fallback_title=fallback_title
    )


def _strip_chunk_suffix(title: str) -> str:
    """Remove the ingestion suffix ``" \u00b7 chunk N"`` from a chunk title."""
    sep = "\u00b7 chunk"
    idx = title.find(sep)
    if idx == -1:
        return title.strip()
    return title[:idx].strip().rstrip("-\u2013\u2014").strip()
