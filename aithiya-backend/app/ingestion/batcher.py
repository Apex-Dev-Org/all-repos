from __future__ import annotations

from collections.abc import Iterator, Sequence


def batched(seq: Sequence[str], batch_size: int) -> Iterator[list[str]]:
    batch: list[str] = []
    for item in seq:
        batch.append(item)
        if len(batch) >= batch_size:
            yield batch
            batch = []
    if batch:
        yield batch
