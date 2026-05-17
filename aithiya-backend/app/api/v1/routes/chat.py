from uuid import UUID

from fastapi import APIRouter, File, Form, Request, UploadFile
from fastapi.responses import StreamingResponse

from app.api.deps import GeminiDep, SbUserDep, SettingsDep, UserDep
from app.api.middleware import limiter
from app.application import chat_service
from app.schemas.chat import ChatResponse
from app.utils.chat_attachments import read_chat_attachments

router = APIRouter(prefix="/chat", tags=["chat"])


def _truthy_optional_int(raw: str | None) -> int | None:
    if raw is None or raw.strip() == "":
        return None
    try:
        v = int(raw)
    except ValueError as exc:
        from app.core.exceptions import ValidationAppError

        raise ValidationAppError("rag_top_k must be an integer") from exc
    if not 1 <= v <= 50:
        from app.core.exceptions import ValidationAppError

        raise ValidationAppError("rag_top_k must be between 1 and 50")
    return v


def _truthy_optional_bool(raw: str | None) -> bool | None:
    if raw is None or raw.strip() == "":
        return None
    s = raw.strip().lower()
    if s in {"true", "1", "yes"}:
        return True
    if s in {"false", "0", "no"}:
        return False
    from app.core.exceptions import ValidationAppError

    raise ValidationAppError("only_in_effect must be a boolean")


def _truthy_optional_uuid(raw: str | None) -> UUID | None:
    if raw is None or raw.strip() == "":
        return None
    try:
        return UUID(raw.strip())
    except ValueError as exc:
        from app.core.exceptions import ValidationAppError

        raise ValidationAppError("thread_id must be a valid UUID") from exc


@router.post("", response_model=ChatResponse)
@limiter.limit("60/minute")
async def chat_sync(
    request: Request,
    sb: SbUserDep,
    user: UserDep,
    gemini: GeminiDep,
    settings: SettingsDep,
    message: str = Form(...),
    thread_id_raw: str | None = Form(None, alias="thread_id"),
    rag_top_k_raw: str | None = Form(None, alias="rag_top_k"),
    only_in_effect_raw: str | None = Form(None, alias="only_in_effect"),
    files: list[UploadFile] | None = File(None),
):
    thread_id = _truthy_optional_uuid(thread_id_raw)
    rag_top_k = _truthy_optional_int(rag_top_k_raw)
    only_in_effect = _truthy_optional_bool(only_in_effect_raw)

    uploads = files or ()
    attachments = await read_chat_attachments(uploads, settings=settings)

    return await chat_service.complete_chat_exchange(
        client=sb,
        gemini=gemini,
        settings=settings,
        user_id=user.id,
        message=message,
        thread_id=thread_id,
        rag_top_k=rag_top_k,
        only_in_effect=only_in_effect,
        attachments=attachments,
    )


@router.post("/stream")
@limiter.limit("60/minute")
async def chat_stream(
    request: Request,
    sb: SbUserDep,
    user: UserDep,
    gemini: GeminiDep,
    settings: SettingsDep,
    message: str = Form(...),
    thread_id_raw: str | None = Form(None, alias="thread_id"),
    rag_top_k_raw: str | None = Form(None, alias="rag_top_k"),
    only_in_effect_raw: str | None = Form(None, alias="only_in_effect"),
    files: list[UploadFile] | None = File(None),
):
    thread_id = _truthy_optional_uuid(thread_id_raw)
    rag_top_k = _truthy_optional_int(rag_top_k_raw)
    only_in_effect = _truthy_optional_bool(only_in_effect_raw)
    uploads = files or ()
    attachments = await read_chat_attachments(uploads, settings=settings)

    gen = chat_service.stream_chat_sse(
        client=sb,
        gemini=gemini,
        settings=settings,
        user_id=user.id,
        message=message,
        thread_id=thread_id,
        rag_top_k=rag_top_k,
        only_in_effect=only_in_effect,
        attachments=attachments,
    )
    return StreamingResponse(gen, media_type="text/event-stream; charset=utf-8")
