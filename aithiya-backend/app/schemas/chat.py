from uuid import UUID

from pydantic import BaseModel, Field


class Citation(BaseModel):
    """One retrieved legal source rendered for the API client.

    ``index`` is the bracketed number the LLM is instructed to emit
    inline (e.g. ``[1]``). The frontend can resolve ``[N]`` markers
    using this list.

    ``doc_id`` is the internal Supabase row id; the LLM is told never
    to render it. ``citation_label`` is the long human-readable form
    suitable for a sources list; ``compact_label`` is the short form
    used when the backend substitutes inline ``[N]`` markers.
    """

    index: int = Field(ge=1)
    doc_id: UUID | str
    act_name: str | None = None
    act_no: str | None = None
    section: str | None = None
    article: str | None = None
    regulation_name: str | None = None
    chapter: str | None = None
    year: str | None = None
    jurisdiction: str | None = None
    title: str | None = None
    citation_label: str
    compact_label: str
    similarity: float | None = None
    content_excerpt: str | None = None


class WebSource(BaseModel):
    """An external page surfaced by Gemini's Google Search grounding."""

    title: str | None = None
    uri: str
    snippet: str | None = None


class AttachmentMeta(BaseModel):
    filename: str
    mime_type: str
    size: int = Field(ge=0)


class ChatResponse(BaseModel):
    thread_id: UUID
    user_message_id: UUID
    assistant_message_id: UUID | None = None
    answer: str
    sources: list[Citation]
    web_sources: list[WebSource] = Field(default_factory=list)
    attachments: list[AttachmentMeta] = Field(default_factory=list)


class SSEEvent(BaseModel):
    type: str
    delta: str | None = None
    items: list[Citation] | None = None
    text: str | None = None
