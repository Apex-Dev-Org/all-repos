import asyncio
from pathlib import Path


async def ensure_dir(path: Path) -> None:
    await asyncio.to_thread(lambda: path.mkdir(parents=True, exist_ok=True))
