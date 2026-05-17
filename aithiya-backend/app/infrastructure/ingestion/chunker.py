from __future__ import annotations


def chunk_markdown(md: str, max_chars: int, overlap: int) -> list[str]:
    md = md.strip()
    if not md:
        return []

    paragraphs = [p.strip() for p in md.split("\n\n") if p.strip()]
    chunks: list[str] = []
    buf = ""

    def flush_buf():
        nonlocal buf
        buf = buf.strip()
        if buf:
            chunks.append(buf)

    for para in paragraphs:
        candidate = para if not buf else buf + "\n\n" + para
        if len(candidate) <= max_chars:
            buf = candidate
            continue
        if buf:
            flush_buf()
        if len(para) <= max_chars:
            buf = para
            continue

        start = 0
        while start < len(para):
            end = min(start + max_chars, len(para))
            piece = para[start:end].strip()
            if piece:
                chunks.append(piece)
            start = max(end - overlap, start + 1)

        buf = ""

    flush_buf()
    return chunks
