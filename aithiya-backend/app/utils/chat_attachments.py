"""Validation and parsing of multipart chat uploads (in-memory only)."""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

from fastapi import UploadFile

from app.core.config import Settings
from app.core.exceptions import UnsupportedMediaAppError, ValidationAppError
from app.domain.attachment import ChatAttachment

_REJECTED_MEDIA = frozenset(
    {
        "text/csv",
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "application/zip",
    }
)

_REJECTED_MEDIA_PREFIXES = ("video/", "audio/")

_ALLOWED_MEDIA = frozenset(
    {
        "application/pdf",
        "image/png",
        "image/jpeg",
        "image/webp",
        "text/plain",
        "text/markdown",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    }
)

MIME_BY_SUFFIX: dict[str, str] = {
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".txt": "text/plain",
    ".md": "text/markdown",
    ".markdown": "text/markdown",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}


def _mime_matches_rejected(declared: str) -> bool:
    d = declared.lower().strip()
    if d in _REJECTED_MEDIA:
        return True
    return any(d.startswith(pref) for pref in _REJECTED_MEDIA_PREFIXES)


def _effective_mime(file: UploadFile) -> tuple[str, str]:
    """Return (effective mimeType, logical filename)."""
    name_raw = file.filename.strip() if file.filename else ""
    suf = Path(name_raw).suffix.lower() if name_raw else ""

    inferred = MIME_BY_SUFFIX.get(suf)

    raw = file.content_type or ""
    ct = raw.split(";")[0].strip().lower() if raw else ""

    if ct and _mime_matches_rejected(ct):
        raise UnsupportedMediaAppError(f"Rejected file type: {ct}")

    if suf == ".doc" or ct == "application/msword":
        raise UnsupportedMediaAppError(
            "Legacy .doc Word format is not supported; use .docx or PDF.",
        )

    if inferred:
        mime = inferred
    elif ct and ct not in {"", "application/octet-stream"}:
        mime = ct
    else:
        mime = None

    display_name = Path(name_raw).name if name_raw else "attachment"

    if mime is None:
        raise UnsupportedMediaAppError(
            f"Could not detect file type for '{display_name}'."
            " Use a PDF, DOCX, image (png/jpeg/webp), or plain-text/markdown file.",
        )

    if _mime_matches_rejected(mime):
        raise UnsupportedMediaAppError(f"Rejected file type: {mime}")

    if mime not in _ALLOWED_MEDIA:
        raise UnsupportedMediaAppError(
            f"Unsupported file type for '{display_name}' (mime={mime}).",
        )

    return mime, display_name


async def read_chat_attachments(
    uploads: Sequence[UploadFile] | None,
    *,
    settings: Settings,
) -> list[ChatAttachment]:
    uploads = uploads or ()
    max_per = settings.max_upload_mb * 1024 * 1024
    total_max = settings.max_chat_total_mb * 1024 * 1024

    attachments: list[ChatAttachment] = []
    combined = 0

    for up in uploads:
        if not getattr(up, "filename", None):
            continue
        mime, fname = _effective_mime(up)

        buf = bytearray()
        size = 0
        while True:
            chunk = await up.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > max_per:
                raise ValidationAppError(f"Attachment '{fname}' exceeds per-file upload limit.")
            combined += len(chunk)
            if combined > total_max:
                raise ValidationAppError("Combined attachments exceed the allowed total size.")
            buf.extend(chunk)
        attachments.append(ChatAttachment(filename=fname, mime_type=mime, data=bytes(buf)))

    return attachments
