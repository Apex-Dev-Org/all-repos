from app.application import chat_service


def test_simple_social_reply_handles_greeting_without_rag():
    reply = chat_service._simple_social_reply("hi", attachments=[])

    assert reply is not None
    assert "Aithiya" in reply


def test_simple_social_reply_ignores_legal_question():
    reply = chat_service._simple_social_reply(
        "hi, can my landlord evict me tomorrow?",
        attachments=[],
    )

    assert reply is None


def test_simple_social_reply_ignores_attachments():
    reply = chat_service._simple_social_reply("hi", attachments=[object()])

    assert reply is None
