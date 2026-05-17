"""Heuristic-gated Gemini Google Search grounding.

We attach Gemini's ``google_search`` tool to a generate call only when
the user's query plausibly needs real-world current information (e.g.
"phone number of the Bar Association", "address of Colombo District
Court"). Statutory content always comes from the vector store; web
grounding is reserved for contact / location / hours-of-operation
style lookups that the model legitimately cannot answer offline.

The decision is intentionally a cheap keyword scan rather than another
LLM call: it must be deterministic, cheap, and easy to tune via the
``WEB_GROUNDING_KEYWORDS`` env var.
"""

from __future__ import annotations

from google.genai import types

from app.core.config import Settings
from app.schemas.chat import WebSource


def _normalize_keywords(raw: str) -> list[str]:
    return [k.strip().lower() for k in raw.split(",") if k.strip()]


def should_enable_web_search(query: str, settings: Settings) -> bool:
    """Return True if ``query`` mentions a contact-info keyword.

    Matching is case-insensitive substring. Sinhala / Tamil terms are
    matched directly (their lowercasing is a no-op).
    """
    if not settings.enable_web_grounding:
        return False
    if not query:
        return False
    q = query.strip().lower()
    if not q:
        return False
    keywords = _normalize_keywords(settings.web_grounding_keywords)
    return any(kw in q for kw in keywords)


def build_search_tool() -> types.Tool:
    """Construct the Gemini Google Search tool."""
    return types.Tool(google_search=types.GoogleSearch())


def extract_web_sources(response: object) -> list[WebSource]:
    """Best-effort extraction of grounding metadata from a Gemini response.

    Different SDK versions expose grounding chunks slightly differently;
    this walks the documented shape and returns ``[]`` on any structural
    surprise rather than raising.
    """
    out: list[WebSource] = []
    try:
        candidates = getattr(response, "candidates", None) or []
        for cand in candidates:
            gm = getattr(cand, "grounding_metadata", None)
            if gm is None:
                continue
            chunks = getattr(gm, "grounding_chunks", None) or []
            for ch in chunks:
                web = getattr(ch, "web", None)
                if web is None:
                    continue
                uri = getattr(web, "uri", None)
                if not uri:
                    continue
                out.append(
                    WebSource(
                        title=getattr(web, "title", None),
                        uri=str(uri),
                        snippet=None,
                    )
                )
    except Exception:
        return out
    seen: set[str] = set()
    deduped: list[WebSource] = []
    for s in out:
        if s.uri in seen:
            continue
        seen.add(s.uri)
        deduped.append(s)
    return deduped
