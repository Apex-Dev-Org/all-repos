"""Verify the Gemini Content list is built correctly with history + attachments."""

from app.domain.attachment import ChatAttachment
from app.infrastructure.ai.generation import HistoryTurn, build_generate_contents


def test_contents_with_no_history_or_attachments_has_only_current_turn():
    out = build_generate_contents("hello", attachments=None, history=None)
    assert len(out) == 1
    assert out[0].role == "user"
    assert out[0].parts and out[0].parts[0].text == "hello"


def test_contents_with_history_orders_history_before_current():
    history = [
        HistoryTurn(role="user", content="first user"),
        HistoryTurn(role="assistant", content="first assistant"),
    ]
    out = build_generate_contents("now", attachments=None, history=history)
    assert len(out) == 3
    assert out[0].role == "user"
    assert out[0].parts[0].text == "first user"
    assert out[1].role == "model"  # assistant -> model
    assert out[1].parts[0].text == "first assistant"
    assert out[2].role == "user"
    assert out[2].parts[0].text == "now"


def test_contents_skips_blank_history_entries():
    history = [
        HistoryTurn(role="user", content=""),
        HistoryTurn(role="assistant", content="  "),
        HistoryTurn(role="user", content="real"),
    ]
    out = build_generate_contents("now", attachments=None, history=history)
    assert len(out) == 3
    assert out[0].parts[0].text == "real"


def test_contents_includes_image_attachment_part():
    att = ChatAttachment(filename="x.png", mime_type="image/png", data=b"\x89PNG")
    out = build_generate_contents("describe", attachments=[att], history=None)
    assert len(out) == 1
    parts = out[0].parts
    assert len(parts) == 2
    assert parts[0].text == "describe"
    inline = getattr(parts[1], "inline_data", None)
    assert inline is not None
    assert inline.mime_type == "image/png"


def test_contents_includes_pdf_attachment_part():
    att = ChatAttachment(filename="doc.pdf", mime_type="application/pdf", data=b"%PDF-")
    out = build_generate_contents("read", attachments=[att], history=None)
    parts = out[0].parts
    assert len(parts) == 2
    inline = getattr(parts[1], "inline_data", None)
    assert inline is not None
    assert inline.mime_type == "application/pdf"


def test_text_attachment_inlined_as_text_part():
    att = ChatAttachment(filename="note.txt", mime_type="text/plain", data=b"hello world")
    out = build_generate_contents("summarize", attachments=[att], history=None)
    parts = out[0].parts
    assert len(parts) == 2
    assert "hello world" in (parts[1].text or "")
    assert "note.txt" in (parts[1].text or "")
