from uuid import uuid4

from app.domain.attachment import ChatAttachment
from app.domain.retrieval import RetrievedChunk
from app.infrastructure.ai.prompts.rag_prompt import (
    build_context_blocks,
    build_system_instruction,
    build_user_prompt,
)
from app.schemas.chat import Citation


def _chunk(title: str, content: str, meta: dict, similarity: float = 0.8) -> RetrievedChunk:
    return RetrievedChunk(
        doc_id=uuid4(),
        title=title,
        content=content,
        metadata=meta,
        similarity=similarity,
    )


def _citation_for(idx: int, label: str) -> Citation:
    return Citation(
        index=idx,
        doc_id=uuid4(),
        title=label,
        citation_label=label,
        compact_label=label,
    )


def test_system_instruction_loads_non_empty():
    text = build_system_instruction()
    assert "Sri Lankan" in text
    assert "Aithiya" in text
    assert "CONTEXT" in text


def test_system_instruction_is_composed_from_section_files():
    text = build_system_instruction()
    assert "Identity & scope" in text
    assert "Language policy" in text
    assert "Citation formatting" in text
    assert "Safety & guardrails" in text
    assert "Output discipline" in text


def test_context_blocks_use_numeric_markers_not_uuids():
    chunk = _chunk("Penal Code \u00b7 chunk 12", "Murder is...", {"act_name": "Penal Code", "section": "302"})
    cite = _citation_for(1, "Penal Code, s. 302")
    out = build_context_blocks([chunk], [cite])
    assert out.startswith("[1] Penal Code, s. 302")
    assert "EXCERPT:" in out
    assert str(chunk.doc_id) not in out


def test_context_blocks_handle_missing_citation_with_title_fallback():
    chunk = _chunk("Constitution \u00b7 chunk 1", "Article 12 says...", {})
    out = build_context_blocks([chunk], [])
    assert "[1] Constitution" in out
    assert str(chunk.doc_id) not in out


def test_context_blocks_empty_chunks():
    out = build_context_blocks([], [])
    assert "no excerpts" in out.lower()


def test_user_prompt_first_turn_includes_intro_hint():
    chunk = _chunk("Penal Code \u00b7 chunk 1", "X", {"act_name": "Penal Code"})
    cite = _citation_for(1, "Penal Code")
    prompt = build_user_prompt(
        "What is murder?", [chunk], [cite], attachments=(), is_first_turn=True
    )
    assert "first turn" in prompt.lower()
    assert "What is murder?" in prompt


def test_user_prompt_continuing_turn_no_intro():
    chunk = _chunk("X \u00b7 chunk 1", "Y", {"act_name": "X"})
    cite = _citation_for(1, "X")
    prompt = build_user_prompt(
        "Follow up?", [chunk], [cite], attachments=(), is_first_turn=False
    )
    assert "continuing thread" in prompt.lower()
    assert "do not re-introduce" in prompt.lower()


def test_user_prompt_with_attachments_lists_filenames():
    chunk = _chunk("X \u00b7 chunk 1", "Y", {"act_name": "X"})
    cite = _citation_for(1, "X")
    att = ChatAttachment(filename="notice.pdf", mime_type="application/pdf", data=b"x")
    prompt = build_user_prompt(
        "What does this notice say?",
        [chunk],
        [cite],
        attachments=(att,),
        is_first_turn=False,
    )
    assert "notice.pdf" in prompt
    assert "application/pdf" in prompt
    assert "user-supplied evidence" in prompt
