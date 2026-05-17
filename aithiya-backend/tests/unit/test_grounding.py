from app.core.config import Settings, get_settings
from app.infrastructure.ai.grounding import (
    extract_web_sources,
    should_enable_web_search,
)


def _settings(**overrides) -> Settings:
    base = get_settings()
    return base.model_copy(update=overrides)


def test_default_keywords_match_english_contact_queries():
    s = _settings()
    assert should_enable_web_search("What is the phone number of the Bar Association?", s)
    assert should_enable_web_search("Where can I CALL the Legal Aid Commission?", s)
    assert should_enable_web_search("Office hours of the Colombo Magistrate Court?", s)


def test_default_keywords_match_sinhala_contact_query():
    s = _settings()
    assert should_enable_web_search(
        "\u0db1\u0dd3\u0adf \u0dc3\u0dc4\u0dba \u0d9a\u0dcf\u0dbb\u0dca\u0dba\u0dcf\u0d82\u0dc1"
        "\u0dba\u0dda \u0daf\u0dd4\u0dbb\u0d9a\u0dad\u0db1 \u0d85\u0d82\u0d9a\u0dba "
        "\u0d9a\u0dd4\u0db8\u0d9a\u0dca\u0daf?",
        s,
    )


def test_default_keywords_match_tamil_contact_query():
    s = _settings()
    assert should_enable_web_search(
        "\u0b9a\u0b9f\u0bcd\u0b9f \u0b89\u0ba4\u0bb5\u0bbf \u0b86\u0ba3\u0bc8\u0baf"
        "\u0bb0\u0bcd \u0ba4\u0bca\u0bb2\u0bc8\u0baa\u0bc7\u0b9a\u0bbf \u0b8e\u0ba9\u0bcd"
        "\u0ba9?",
        s,
    )


def test_non_contact_query_does_not_trigger():
    s = _settings()
    assert not should_enable_web_search("What is the punishment for theft?", s)
    assert not should_enable_web_search("Explain mens rea.", s)


def test_disabled_flag_returns_false():
    s = _settings(enable_web_grounding=False)
    assert not should_enable_web_search("phone number of court", s)


def test_empty_query_returns_false():
    s = _settings()
    assert not should_enable_web_search("", s)
    assert not should_enable_web_search("   ", s)


def test_extract_web_sources_handles_missing_metadata():
    class FakeResp:
        candidates = []

    assert extract_web_sources(FakeResp()) == []


def test_extract_web_sources_pulls_uri():
    class FakeWeb:
        uri = "https://gov.lk"
        title = "Government of Sri Lanka"

    class FakeChunk:
        web = FakeWeb()

    class FakeGM:
        grounding_chunks = [FakeChunk()]

    class FakeCand:
        grounding_metadata = FakeGM()

    class FakeResp:
        candidates = [FakeCand()]

    sources = extract_web_sources(FakeResp())
    assert len(sources) == 1
    assert sources[0].uri == "https://gov.lk"
    assert sources[0].title == "Government of Sri Lanka"


def test_extract_web_sources_dedupes_by_uri():
    class FakeWeb:
        uri = "https://gov.lk"
        title = "X"

    class FakeChunk:
        web = FakeWeb()

    class FakeGM:
        grounding_chunks = [FakeChunk(), FakeChunk()]

    class FakeCand:
        grounding_metadata = FakeGM()

    class FakeResp:
        candidates = [FakeCand()]

    sources = extract_web_sources(FakeResp())
    assert len(sources) == 1
