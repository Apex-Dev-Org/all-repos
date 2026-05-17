"""End-to-end happy path for /api/v1/chat with mocked Gemini + Supabase.

We do not stand up real upstreams. Instead we monkeypatch the small set
of seams the chat orchestrator relies on:

- ``embed_query`` (returns a fake vector)
- ``match_documents`` (returns synthetic RetrievedChunks)
- ``generate_text`` (returns a templated answer that includes ``[1]``
  markers AND a deliberately-leaked ``[doc:<uuid>]`` to assert the
  renderer scrubs it)
- ``thread_service`` + ``messages_repo`` (in-memory fakes)

This exercises the live wiring end-to-end: prompt building, citation
construction, post-processing, and the JSON response shape returned by
the FastAPI route.
"""

from __future__ import annotations

from uuid import UUID

import pytest
from fastapi.testclient import TestClient

from app.api import deps
from app.application import rag_service, thread_service
from app.domain.retrieval import RetrievedChunk
from app.domain.user import CurrentUser
from app.infrastructure.ai import embeddings, generation
from app.infrastructure.db.repositories import messages_repo
from app.infrastructure.retrieval import vector_search

_FIXED_USER_ID = UUID("11111111-1111-1111-1111-111111111111")
_FIXED_THREAD_ID = UUID("22222222-2222-2222-2222-222222222222")
_FIXED_USER_MSG_ID = UUID("33333333-3333-3333-3333-333333333333")
_FIXED_ASSISTANT_MSG_ID = UUID("44444444-4444-4444-4444-444444444444")
_FIXED_DOC_ID = UUID("55555555-5555-5555-5555-555555555555")


class _FakeSupabaseClient:
    def __init__(self) -> None:
        self.messages: list[dict] = []


@pytest.fixture()
def patched_app(monkeypatch):
    fake_sb = _FakeSupabaseClient()

    class _FakeGemini:
        pass

    fake_gemini = _FakeGemini()

    async def _fake_user():
        return CurrentUser(id=_FIXED_USER_ID, email="t@example.com")

    async def _fake_sb_user():
        return fake_sb

    def _fake_sb_service():
        return fake_sb

    def _fake_gemini_dep():
        return fake_gemini

    from app.main import app

    app.dependency_overrides[deps.get_current_user] = _fake_user
    app.dependency_overrides[deps.supabase_for_user] = _fake_sb_user
    app.dependency_overrides[deps.get_supabase_service] = _fake_sb_service
    app.dependency_overrides[deps.get_genai_client] = _fake_gemini_dep
    app.dependency_overrides[deps.get_token] = lambda: "tok"

    async def _fake_create_thread(client, *, user_id, title):
        return {"id": str(_FIXED_THREAD_ID)}

    async def _fake_require_owned(client, *, thread_id, user_id):
        return {"id": str(thread_id), "user_id": str(user_id)}

    monkeypatch.setattr(thread_service, "create_thread", _fake_create_thread)
    monkeypatch.setattr(thread_service, "require_owned", _fake_require_owned)

    insert_calls: list[dict] = []

    async def _fake_insert_message(client, *, thread_id, user_id, role, content, sources):
        mid = _FIXED_USER_MSG_ID if role == "user" else _FIXED_ASSISTANT_MSG_ID
        row = {
            "id": str(mid),
            "thread_id": str(thread_id),
            "user_id": str(user_id),
            "role": role,
            "content": content,
            "sources": sources,
        }
        insert_calls.append(row)
        return row

    async def _fake_recent_messages(client, *, thread_id, user_id, limit):
        return []

    monkeypatch.setattr(messages_repo, "insert_message", _fake_insert_message)
    monkeypatch.setattr(messages_repo, "recent_messages", _fake_recent_messages)

    async def _fake_embed(client, settings, text):
        return [0.0] * 768

    async def _fake_match(
        client, settings, embedding, match_count=None, only_in_effect=None, filter_metadata=None
    ):
        return [
            RetrievedChunk(
                doc_id=_FIXED_DOC_ID,
                title="Penal Code \u00b7 chunk 12",
                content="Section 302: Whoever commits murder shall be punished with death...",
                metadata={"act_name": "Penal Code", "act_no": "2 of 1883", "section": "302"},
                similarity=0.91,
            ),
        ]

    monkeypatch.setattr(embeddings, "embed_query", _fake_embed)
    monkeypatch.setattr(vector_search, "match_documents", _fake_match)
    monkeypatch.setattr(rag_service, "embed_query", _fake_embed)
    monkeypatch.setattr(rag_service, "match_documents", _fake_match)

    async def _fake_generate_text(
        client,
        settings,
        *,
        system,
        user,
        attachments=None,
        history=None,
        tools=None,
    ):
        leaked = f"[doc:{_FIXED_DOC_ID}]"
        text = (
            "Under Sri Lankan law, murder is defined and punished under "
            "Section 302 of the Penal Code [1]. " + leaked + " That is the rule."
        )

        class _Resp:
            candidates = []

        return text, _Resp()

    monkeypatch.setattr(generation, "generate_text", _fake_generate_text)
    monkeypatch.setattr(rag_service, "generate_text", _fake_generate_text)

    yield app, fake_sb, insert_calls

    app.dependency_overrides.clear()


def test_chat_endpoint_returns_clean_human_citation(patched_app):
    app, _sb, _inserts = patched_app
    client = TestClient(app)

    resp = client.post(
        "/api/v1/chat",
        data={"message": "What is the punishment for murder?"},
        headers={"Authorization": "Bearer test"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()

    answer = body["answer"]
    assert "[Penal Code, s. 302]" in answer
    assert str(_FIXED_DOC_ID) not in answer
    assert "doc:" not in answer
    assert "[1]" not in answer

    sources = body["sources"]
    assert len(sources) == 1
    src = sources[0]
    assert src["index"] == 1
    assert src["act_name"] == "Penal Code"
    assert src["section"] == "302"
    assert src["citation_label"] == "Penal Code No. 2 of 1883, s. 302"
    assert src["compact_label"] == "Penal Code, s. 302"

    assert body["thread_id"] == str(_FIXED_THREAD_ID)
    assert body["user_message_id"] == str(_FIXED_USER_MSG_ID)
    assert body["assistant_message_id"] == str(_FIXED_ASSISTANT_MSG_ID)
    assert body["attachments"] == []
    assert body["web_sources"] == []


def test_chat_endpoint_accepts_image_upload_and_does_not_leak_id(patched_app):
    app, _sb, _inserts = patched_app
    client = TestClient(app)

    files = {"files": ("photo.png", b"\x89PNG\r\n\x1a\nfake", "image/png")}
    resp = client.post(
        "/api/v1/chat",
        data={"message": "What does this document mean?"},
        files=files,
        headers={"Authorization": "Bearer test"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert "doc:" not in body["answer"]
    assert len(body["attachments"]) == 1
    assert body["attachments"][0]["filename"] == "photo.png"
    assert body["attachments"][0]["mime_type"] == "image/png"


def test_chat_endpoint_refuses_clearly_unsafe_query(patched_app):
    app, _sb, _inserts = patched_app
    client = TestClient(app)

    resp = client.post(
        "/api/v1/chat",
        data={"message": "Teach me how to forge a court summons signature."},
        headers={"Authorization": "Bearer test"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["sources"] == []
    assert "can't help" in body["answer"].lower() or "cannot help" in body["answer"].lower()
