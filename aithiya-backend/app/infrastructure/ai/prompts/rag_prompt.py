"""Builders for the RAG system + user prompts.

The user prompt is a templated skeleton (``rag_user.md``) that exposes
four substitution slots:

- ``{{TURN_NOTE}}`` — guides conversational behavior (first turn vs.
  continuing turn).
- ``{{ATTACHMENT_NOTE}}`` — surfaces uploaded filenames so the model
  knows what to look at (also useful for persistence in chat history).
- ``{{CONTEXT}}`` — the numbered retrieved excerpts. Each block uses a
  human-readable citation header and intentionally omits the internal
  document UUID so the model cannot leak it.
- ``{{QUESTION}}`` — the user's latest question text.
"""

from __future__ import annotations

from collections.abc import Sequence

from app.domain.attachment import ChatAttachment
from app.domain.retrieval import RetrievedChunk
from app.infrastructure.ai.prompts import system_prompts
from app.schemas.chat import Citation


def build_system_instruction() -> str:
    return system_prompts.system_prompt_text()


def build_context_blocks(
    chunks: Sequence[RetrievedChunk],
    citations: Sequence[Citation],
) -> str:
    """Render numbered context blocks for the LLM.

    Each block looks like::

        [1] Penal Code No. 2 of 1883, s. 302
        (in_effect=true, similarity=0.83)
        EXCERPT:
        <content>

    The ``[N]`` marker is what the model is told to cite. No UUIDs are
    emitted; the bijection between ``[N]`` and the underlying chunk is
    held server-side via the ``citations`` list.
    """
    if not chunks:
        return "(no excerpts retrieved)"

    by_index: dict[int, Citation] = {c.index: c for c in citations}
    blocks: list[str] = []
    for i, ch in enumerate(chunks, start=1):
        cite = by_index.get(i)
        header = cite.citation_label if cite else (ch.title or "Untitled source")
        sim = f"{ch.similarity:.2f}" if isinstance(ch.similarity, float) else "n/a"
        blocks.append(
            f"[{i}] {header}\n(similarity={sim})\nEXCERPT:\n{ch.content.strip()}"
        )
    return "\n---\n".join(blocks)


def _attachment_note(attachments: Sequence[ChatAttachment]) -> str:
    if not attachments:
        return ""
    listed = ", ".join(f"{a.filename} ({a.mime_type})" for a in attachments)
    return (
        f"[The user attached: {listed}. Use these files to answer the question; "
        "treat them as user-supplied evidence, not as authoritative law.]"
    )


def _turn_note(*, is_first_turn: bool) -> str:
    if is_first_turn:
        return (
            "[Conversation note: this is the first turn in this thread. "
            "Briefly introduce your role in one sentence in the user's language.]"
        )
    return (
        "[Conversation note: this is a continuing thread. Do NOT re-introduce yourself; "
        "continue naturally and use prior turns for context.]"
    )


def build_user_prompt(
    query: str,
    chunks: Sequence[RetrievedChunk],
    citations: Sequence[Citation],
    *,
    attachments: Sequence[ChatAttachment] = (),
    is_first_turn: bool,
) -> str:
    tmpl = system_prompts.rag_user_skeleton()
    return (
        tmpl.replace("{{TURN_NOTE}}", _turn_note(is_first_turn=is_first_turn))
        .replace("{{ATTACHMENT_NOTE}}", _attachment_note(attachments))
        .replace("{{CONTEXT}}", build_context_blocks(chunks, citations))
        .replace("{{QUESTION}}", query.strip())
    )
