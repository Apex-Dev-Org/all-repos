from pathlib import Path


def load_template(name: str) -> str:
    here = Path(__file__).resolve().parent / "templates" / name

    return here.read_text(encoding="utf-8")


def system_prompt_for(language_key: str) -> str:
    key = {"en": "system_en.md", "si": "system_si.md", "ta": "system_ta.md"}.get(
        language_key, "system_en.md"
    )

    return load_template(key)


def rag_user_skeleton() -> str:
    return load_template("rag_user.md")
