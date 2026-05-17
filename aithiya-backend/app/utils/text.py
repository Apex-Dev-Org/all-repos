from __future__ import annotations


def normalize_query(text: str) -> str:
    text = text.replace("\ufeff", "").strip()
    lines = [line.strip() for line in text.splitlines()]
    return "\n".join(lines)
