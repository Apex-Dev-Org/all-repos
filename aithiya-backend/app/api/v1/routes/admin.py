import json
import uuid
from pathlib import Path
from uuid import UUID

import aiofiles
from fastapi import APIRouter, Form, Query, Request, UploadFile

from app.api.deps import AdminDep, GeminiDep, SbServiceDep, SettingsDep
from app.api.middleware import limiter
from app.application import document_service, ingestion_service
from app.core.config import Settings
from app.core.exceptions import ValidationAppError
from app.schemas.document import LegalDocumentsPage, ListedDocument
from app.schemas.ingest import IngestionReport
from app.utils.files import ensure_dir

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/documents", response_model=LegalDocumentsPage)
async def admin_list_documents(
    _: AdminDep,
    svc: SbServiceDep,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    only_in_effect: bool | None = Query(None),
):
    rows = await document_service.list_summaries(
        svc, limit=limit, offset=offset, only_in_effect=only_in_effect
    )
    items = [ListedDocument.model_validate(r) for r in rows]
    return LegalDocumentsPage(items=items)


@router.delete("/documents/{doc_id}")
async def admin_delete_document(_: AdminDep, svc: SbServiceDep, doc_id: UUID):
    await document_service.remove(svc, doc_id=doc_id)
    return {"deleted": True}


def _parse_metadata(metadata_json: str) -> dict:
    try:
        meta = json.loads(metadata_json or "{}")
    except json.JSONDecodeError as exc:
        raise ValidationAppError("metadata_json must be valid JSON") from exc
    if not isinstance(meta, dict):
        raise ValidationAppError("metadata_json must be a JSON object")
    return meta


async def _stage_upload(file: UploadFile, settings: Settings) -> Path:
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise ValidationAppError("Only PDF uploads are supported")

    dest_dir = Path(settings.temp_dir).resolve()
    await ensure_dir(dest_dir)
    dest = dest_dir / f"{uuid.uuid4()}.pdf"
    max_bytes = settings.max_upload_mb * 1024 * 1024
    size = 0
    try:
        async with aiofiles.open(dest, "wb") as out:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > max_bytes:
                    raise ValidationAppError("File too large")
                await out.write(chunk)
    except BaseException:
        dest.unlink(missing_ok=True)
        raise
    return dest


@router.post("/ingest", response_model=IngestionReport)
@limiter.limit("10/minute")
async def admin_ingest_pdf(
    request: Request,
    admin: AdminDep,
    svc: SbServiceDep,
    gemini: GeminiDep,
    settings: SettingsDep,
    file: UploadFile,
    title_prefix: str | None = Form(None),
    metadata_json: str = Form("{}"),
):
    meta = _parse_metadata(metadata_json)
    stem = Path(file.filename).stem if file.filename else "document"
    prefix = (title_prefix or stem).strip() or "Legal document"

    dest = await _stage_upload(file, settings)
    try:
        return await ingestion_service.ingest_uploaded_pdf(
            pdf_path=dest,
            gemini_client=gemini,
            service_client=svc,
            settings=settings,
            admin_id=admin.id,
            title_prefix=prefix,
            extra_metadata=meta,
        )
    finally:
        dest.unlink(missing_ok=True)


@router.post("/ingest/resume", response_model=IngestionReport)
@limiter.limit("10/minute")
async def admin_resume_ingest(
    request: Request,
    admin: AdminDep,
    svc: SbServiceDep,
    gemini: GeminiDep,
    settings: SettingsDep,
    file: UploadFile,
    ingest_id: UUID = Form(...),
    title_prefix: str | None = Form(None),
    metadata_json: str = Form("{}"),
):
    meta = _parse_metadata(metadata_json)
    stem = Path(file.filename).stem if file.filename else "document"
    prefix = (title_prefix or stem).strip() or "Legal document"

    dest = await _stage_upload(file, settings)
    try:
        return await ingestion_service.resume_uploaded_pdf(
            pdf_path=dest,
            gemini_client=gemini,
            service_client=svc,
            settings=settings,
            admin_id=admin.id,
            title_prefix=prefix,
            extra_metadata=meta,
            ingest_id=ingest_id,
        )
    finally:
        dest.unlink(missing_ok=True)
