from app.domain.citation import (
    build_citation_label,
    build_compact_citation_label,
    extract_citation_parts,
)


def test_full_act_with_number_and_section():
    meta = {"act_name": "Penal Code", "act_no": "2 of 1883", "section": "302"}
    assert build_citation_label(meta) == "Penal Code No. 2 of 1883, s. 302"
    assert build_compact_citation_label(meta) == "Penal Code, s. 302"


def test_constitution_article():
    meta = {"act_name": "Constitution", "article": "12(1)"}
    assert build_citation_label(meta) == "Constitution, Art. 12(1)"
    assert build_compact_citation_label(meta) == "Constitution, Art. 12(1)"


def test_regulation_only():
    meta = {"regulation_name": "Motor Traffic Regulations 1984"}
    assert build_citation_label(meta) == "Motor Traffic Regulations 1984"


def test_year_fallback_when_no_number():
    meta = {"act_name": "Online Safety Act", "year": "2024", "section": "10"}
    assert build_citation_label(meta) == "Online Safety Act (2024), s. 10"
    assert build_compact_citation_label(meta) == "Online Safety Act, s. 10"


def test_fallback_to_title_strips_chunk_suffix_for_unknown_act():
    meta: dict = {}
    label = build_citation_label(
        meta, fallback_title="Some Random Unregistered Act \u00b7 chunk 12"
    )
    assert label == "Some Random Unregistered Act"


def test_fallback_resolves_registered_act_code():
    meta: dict = {}
    label = build_citation_label(meta, fallback_title="CIVIL-PROCEDURE-CODE \u00b7 chunk 17")
    assert label == "Civil Procedure Code No. 2 of 1889"
    compact = build_compact_citation_label(
        meta, fallback_title="CIVIL-PROCEDURE-CODE \u00b7 chunk 17"
    )
    assert compact == "Civil Procedure Code"


def test_fallback_registry_does_not_override_metadata():
    meta = {"act_name": "Bespoke Override", "section": "9"}
    label = build_citation_label(meta, fallback_title="CIVIL-PROCEDURE-CODE \u00b7 chunk 1")
    assert label == "Bespoke Override, s. 9"


def test_fallback_to_untitled_when_nothing():
    assert build_citation_label({}) == "Untitled source"
    assert build_compact_citation_label({}) == "Untitled source"


def test_extract_picks_alternate_keys():
    parts = extract_citation_parts({"statute": "Civil Procedure Code", "sec": "5"})
    assert parts.act_name == "Civil Procedure Code"
    assert parts.section == "5"


def test_chapter_locator():
    meta = {"act_name": "Code of Criminal Procedure", "chapter": "XIII"}
    assert build_citation_label(meta) == "Code of Criminal Procedure, ch. XIII"
