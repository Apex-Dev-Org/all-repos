from __future__ import annotations

import json
from typing import Any


def sse_data(obj: dict[str, Any]) -> str:
    payload = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
    return f"data: {payload}\n\n"


def sse_ping() -> str:
    return ": ping\n\n"
