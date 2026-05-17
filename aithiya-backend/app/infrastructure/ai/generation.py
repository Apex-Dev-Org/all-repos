from __future__ import annotations

from collections.abc import AsyncIterator, Sequence
from dataclasses import dataclass
from io import BytesIO

from docx import Document
from google import genai
from google.genai import types
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import Settings
from app.core.exceptions import UnsupportedMediaAppError, UpstreamAIError
from app.domain.attachment import ChatAttachment


@dataclass(slots=True, frozen=True)
class HistoryTurn:
    """One previously-persisted turn passed back to the model.

    ``role`` is the API-level role (``"user"`` or ``"assistant"``); we
    map ``"assistant"`` to Gemini's ``"model"`` when constructing
    Contents.
    """

    role: str
    content: str


def _truncate_text(s: str, max_len: int = 120_000) -> str:
    if len(s) <= max_len:
        return s
    return s[:max_len] + "\n...[truncated]..."


def _docx_plain_text(data: bytes) -> str:
    doc = Document(BytesIO(data))
    paragraphs = [p.text.strip() for p in doc.paragraphs if p.text and p.text.strip()]
    return "\n".join(paragraphs)


def _parts_for_attachment(att: ChatAttachment) -> list[types.Part]:
    mt = att.mime_type
    fname = att.filename or "attachment"

    if mt == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
        extracted = _docx_plain_text(att.data).strip() or "(empty document)"
        block = _truncate_text(f"\n\n[Attached DOCX file: {fname}]\n{extracted}\n\n")
        return [types.Part.from_text(text=block)]

    if mt == "application/msword":
        raise UnsupportedMediaAppError(
            "Legacy .doc Word format is not supported; please upload .docx or PDF.",
        )

    if mt == "application/pdf":
        return [types.Part.from_bytes(data=att.data, mime_type=mt)]

    if mt in {"image/png", "image/jpeg", "image/webp"}:
        return [types.Part.from_bytes(data=att.data, mime_type=mt)]

    if mt == "text/plain":
        decoded = att.data.decode("utf-8", errors="replace")
        block = _truncate_text(f"\n\n[Attached text file: {fname}]\n{decoded}\n\n")
        return [types.Part.from_text(text=block)]

    if mt == "text/markdown":
        decoded = att.data.decode("utf-8", errors="replace")
        block = _truncate_text(f"\n\n[Attached markdown file: {fname}]\n{decoded}\n\n")
        return [types.Part.from_text(text=block)]

    raise UnsupportedMediaAppError(f"Unsupported attachment type: {mt}")


def _user_turn_content(
    user_text: str,
    attachments: Sequence[ChatAttachment],
) -> types.Content:
    parts: list[types.Part] = [types.Part.from_text(text=user_text)]
    for att in attachments:
        parts.extend(_parts_for_attachment(att))
    return types.Content(role="user", parts=parts)


def _history_contents(history: Sequence[HistoryTurn]) -> list[types.Content]:
    out: list[types.Content] = []
    for turn in history:
        text = (turn.content or "").strip()
        if not text:
            continue
        role = "model" if turn.role == "assistant" else "user"
        out.append(types.Content(role=role, parts=[types.Part.from_text(text=text)]))
    return out


def build_generate_contents(
    user_text: str,
    attachments: Sequence[ChatAttachment] | None,
    history: Sequence[HistoryTurn] | None = None,
) -> list[types.Content]:
    """Build the full Contents list: history followed by the current user turn."""
    out: list[types.Content] = []
    if history:
        out.extend(_history_contents(history))
    out.append(_user_turn_content(user_text, attachments or ()))
    return out


def _build_config(
    *,
    system: str,
    tools: Sequence[types.Tool] | None,
) -> types.GenerateContentConfig:
    kwargs: dict[str, object] = {
        "system_instruction": system,
        "temperature": 0.2,
    }
    if tools:
        kwargs["tools"] = list(tools)
    return types.GenerateContentConfig(**kwargs)  # type: ignore[arg-type]


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=8))
async def generate_text(
    client: genai.Client,
    settings: Settings,
    *,
    system: str,
    user: str,
    attachments: Sequence[ChatAttachment] | None = None,
    history: Sequence[HistoryTurn] | None = None,
    tools: Sequence[types.Tool] | None = None,
) -> tuple[str, object]:
    """Generate a complete answer.

    Returns ``(text, raw_response)`` so callers can extract grounding
    metadata from the raw response when web search was used.
    """
    contents = build_generate_contents(user, attachments, history)
    try:
        resp = await client.aio.models.generate_content(
            model=settings.gemini_chat_model,
            contents=contents,
            config=_build_config(system=system, tools=tools),
        )
    except Exception as exc:
        raise UpstreamAIError("Gemini generation failed") from exc

    text = getattr(resp, "text", None)
    if not text:
        raise UpstreamAIError("Gemini returned empty body")
    return text, resp


async def generate_text_stream(
    client: genai.Client,
    settings: Settings,
    *,
    system: str,
    user: str,
    attachments: Sequence[ChatAttachment] | None = None,
    history: Sequence[HistoryTurn] | None = None,
    tools: Sequence[types.Tool] | None = None,
) -> AsyncIterator[str]:
    contents = build_generate_contents(user, attachments, history)
    try:
        stream_mgr = await client.aio.models.generate_content_stream(
            model=settings.gemini_chat_model,
            contents=contents,
            config=_build_config(system=system, tools=tools),
        )
    except Exception as exc:
        raise UpstreamAIError("Gemini streaming failed") from exc

    try:
        async for chunk in stream_mgr:
            piece = getattr(chunk, "text", None)
            if piece:
                yield piece
    except Exception as exc:
        raise UpstreamAIError("Gemini streaming interrupted") from exc
