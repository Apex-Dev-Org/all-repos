import asyncio
from pathlib import Path

import pymupdf4llm


async def pdf_path_to_markdown(path: Path) -> str:
    path = path.resolve()

    def _run() -> str:
        md = pymupdf4llm.to_markdown(str(path))
        return md or ""

    return await asyncio.to_thread(_run)
