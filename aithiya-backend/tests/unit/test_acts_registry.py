from app.infrastructure.ai.acts_registry import lookup_act, reload_registry


def setup_function(_func):
    reload_registry()


def test_lookup_by_exact_code():
    rec = lookup_act("CIVIL-PROCEDURE-CODE")
    assert rec is not None
    assert rec.act_name == "Civil Procedure Code"
    assert rec.act_no == "2 of 1889"
    assert rec.year == "1889"


def test_lookup_strips_chunk_suffix():
    rec = lookup_act("CIVIL-PROCEDURE-CODE \u00b7 chunk 17")
    assert rec is not None
    assert rec.act_name == "Civil Procedure Code"


def test_lookup_is_case_insensitive():
    assert lookup_act("civil-procedure-code") is not None
    assert lookup_act("Civil_Procedure_Code") is not None
    assert lookup_act("civil procedure code") is not None


def test_lookup_resolves_alias():
    rec = lookup_act("CPC")
    assert rec is not None
    assert rec.act_name == "Civil Procedure Code"


def test_lookup_unknown_returns_none():
    assert lookup_act("not-a-real-act") is None
    assert lookup_act("") is None
    assert lookup_act(None) is None


def test_lookup_constitution_has_no_act_no():
    rec = lookup_act("CONSTITUTION")
    assert rec is not None
    assert rec.act_no is None
    assert rec.year == "1978"
