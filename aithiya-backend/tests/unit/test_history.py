from uuid import uuid4

import pytest

from app.application import chat_service
from app.core.config import get_settings
from app.infrastructure.ai.generation import HistoryTurn


class _FakeMessagesRepo:
    def __init__(self, rows: list[dict]):
        self.rows = rows
        self.last_args: dict | None = None

    async def recent_messages(self, client, *, thread_id, user_id, limit):
        self.last_args = {"thread_id": thread_id, "user_id": user_id, "limit": limit}
        return self.rows[:limit]


@pytest.mark.asyncio
async def test_load_history_first_turn_when_thread_id_none():
    history, is_first = await chat_service._load_history(
        client=object(),
        settings=get_settings(),
        thread_id=None,
        user_id=uuid4(),
    )
    assert history == []
    assert is_first is True


@pytest.mark.asyncio
async def test_load_history_first_turn_when_empty(monkeypatch):
    fake = _FakeMessagesRepo([])
    monkeypatch.setattr(chat_service.messages_repo, "recent_messages", fake.recent_messages)
    history, is_first = await chat_service._load_history(
        client=object(),
        settings=get_settings(),
        thread_id=uuid4(),
        user_id=uuid4(),
    )
    assert history == []
    assert is_first is True


@pytest.mark.asyncio
async def test_load_history_returns_turns_in_order(monkeypatch):
    rows = [
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": "hello"},
        {"role": "user", "content": "next"},
    ]
    fake = _FakeMessagesRepo(rows)
    monkeypatch.setattr(chat_service.messages_repo, "recent_messages", fake.recent_messages)
    history, is_first = await chat_service._load_history(
        client=object(),
        settings=get_settings(),
        thread_id=uuid4(),
        user_id=uuid4(),
    )
    assert is_first is False
    assert history == [
        HistoryTurn(role="user", content="hi"),
        HistoryTurn(role="assistant", content="hello"),
        HistoryTurn(role="user", content="next"),
    ]


@pytest.mark.asyncio
async def test_load_history_respects_configured_limit(monkeypatch):
    settings = get_settings().model_copy(update={"chat_history_turns": 3})
    fake = _FakeMessagesRepo(
        [{"role": "user", "content": f"m{i}"} for i in range(10)]
    )
    monkeypatch.setattr(chat_service.messages_repo, "recent_messages", fake.recent_messages)
    history, _ = await chat_service._load_history(
        client=object(),
        settings=settings,
        thread_id=uuid4(),
        user_id=uuid4(),
    )
    assert fake.last_args is not None
    assert fake.last_args["limit"] == 3
    assert len(history) == 3


@pytest.mark.asyncio
async def test_load_history_disabled_when_zero():
    settings = get_settings().model_copy(update={"chat_history_turns": 0})
    history, is_first = await chat_service._load_history(
        client=object(),
        settings=settings,
        thread_id=uuid4(),
        user_id=uuid4(),
    )
    assert history == []
    assert is_first is True
