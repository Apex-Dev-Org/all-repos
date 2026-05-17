"""Loaders for the prompt templates shipped with the application.

The production system prompt is assembled at import time from a
directory of small markdown sections — each section owns one concern
(identity, language policy, grounding, citations, web search,
conversation, attachments, guardrails, hallucination prevention,
output discipline). Sections are concatenated in lexical filename
order, which is why the on-disk files are prefixed with ``00_``,
``01_``, etc. Drop in a ``XX_<topic>.md`` to add another section
without touching code; rename to renumber.

The user-turn skeleton (``rag_user.md``) stays as a single file
because it is read by ``rag_prompt.py`` and substituted with the
``{{TURN_NOTE}} / {{ATTACHMENT_NOTE}} / {{CONTEXT}} / {{QUESTION}}``
slots.
"""

from functools import lru_cache
from pathlib import Path

_TEMPLATE_DIR = Path(__file__).resolve().parent / "templates"
_SYSTEM_DIR = _TEMPLATE_DIR / "system"

_SECTION_SEPARATOR = "\n\n---\n\n"


def _load(name: str) -> str:
    return (_TEMPLATE_DIR / name).read_text(encoding="utf-8")


def _iter_system_sections() -> list[Path]:
    if not _SYSTEM_DIR.is_dir():
        return []
    return sorted(p for p in _SYSTEM_DIR.glob("*.md") if p.is_file())


@lru_cache(maxsize=1)
def system_prompt_text() -> str:
    """Return the production legal-assistant system prompt.

    Composed from every ``*.md`` file under
    ``prompts/templates/system/`` in lexical filename order. Empty
    files are skipped so admins can disable a section by emptying it.
    """
    sections: list[str] = []
    for path in _iter_system_sections():
        body = path.read_text(encoding="utf-8").strip()
        if body:
            sections.append(body)
    return _SECTION_SEPARATOR.join(sections) + "\n"


@lru_cache(maxsize=8)
def rag_user_skeleton() -> str:
    """Return the user-turn skeleton used by the RAG prompt builder."""
    return _load("rag_user.md")


def reload_prompts() -> None:
    """Drop cached prompt strings so admins can hot-edit the templates."""
    system_prompt_text.cache_clear()
    rag_user_skeleton.cache_clear()


__all__ = ["rag_user_skeleton", "reload_prompts", "system_prompt_text"]
