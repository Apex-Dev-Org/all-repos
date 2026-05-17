from uuid import uuid4

from app.infrastructure.ai.citation_renderer import (
    render_for_user,
    strip_uuid_citations,
    substitute_inline_markers,
)
from app.schemas.chat import Citation


def _cite(index: int, label: str) -> Citation:
    return Citation(
        index=index,
        doc_id=uuid4(),
        title=label,
        citation_label=label,
        compact_label=label,
    )


def test_substitute_single_marker():
    cites = [_cite(1, "Penal Code, s. 302")]
    out = substitute_inline_markers("Under the law [1], murder is punishable.", cites)
    assert out == "Under the law [Penal Code, s. 302], murder is punishable."


def test_substitute_group_marker():
    cites = [_cite(1, "Penal Code, s. 302"), _cite(2, "Constitution, Art. 12(1)")]
    out = substitute_inline_markers("Multiple sources [1, 2] confirm this.", cites)
    assert out == "Multiple sources [Penal Code, s. 302; Constitution, Art. 12(1)] confirm this."


def test_unknown_marker_dropped():
    cites = [_cite(1, "A")]
    out = substitute_inline_markers("See [1] and [7] for details.", cites)
    assert "[7]" not in out
    assert "[A]" in out


def test_empty_citations_strips_all_markers():
    out = substitute_inline_markers("Refer to [1] and [2].", [])
    assert "[1]" not in out
    assert "[2]" not in out


def test_strip_doc_uuid_in_brackets():
    uid = uuid4()
    text = f"As stated [doc:{uid}], the rule applies."
    assert str(uid) not in strip_uuid_citations(text)
    assert "doc:" not in strip_uuid_citations(text)


def test_strip_bare_uuid_in_brackets():
    uid = uuid4()
    text = f"As stated [{uid}], the rule applies."
    cleaned = strip_uuid_citations(text)
    assert str(uid) not in cleaned


def test_strip_parens_doc_form():
    uid = uuid4()
    text = f"See (doc:{uid}) for more."
    cleaned = strip_uuid_citations(text)
    assert "doc:" not in cleaned


def test_render_for_user_combines_strip_and_substitute():
    uid = uuid4()
    cites = [_cite(1, "Penal Code, s. 302")]
    text = f"Under the law [1] and [doc:{uid}], murder is punishable."
    out = render_for_user(text, cites)
    assert "[Penal Code, s. 302]" in out
    assert str(uid) not in out
    assert "doc:" not in out


def test_no_markers_no_change():
    text = "Plain answer with no citations."
    assert substitute_inline_markers(text, [_cite(1, "X")]) == text
