from uuid import UUID

from fastapi import APIRouter, Query

from app.api.deps import SbUserDep, UserDep
from app.application import thread_service
from app.schemas.thread import ThreadCreate, ThreadOut, ThreadUpdate

router = APIRouter(prefix="/threads", tags=["threads"])


@router.post("", response_model=ThreadOut)
async def create_thread(body: ThreadCreate, sb: SbUserDep, user: UserDep):
    row = await thread_service.create_thread(sb, user_id=user.id, title=body.title or "New chat")
    return ThreadOut.model_validate(row)


@router.get("", response_model=list[ThreadOut])
async def list_threads(
    sb: SbUserDep,
    user: UserDep,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    rows = await thread_service.list_owned(sb, user_id=user.id, limit=limit, offset=offset)
    return [ThreadOut.model_validate(r) for r in rows]


@router.patch("/{thread_id}", response_model=ThreadOut)
async def patch_thread(thread_id: UUID, body: ThreadUpdate, sb: SbUserDep, user: UserDep):
    if not body.title:
        row = await thread_service.require_owned(sb, thread_id=thread_id, user_id=user.id)
        return ThreadOut.model_validate(row)
    row = await thread_service.update_title(
        sb,
        thread_id=thread_id,
        user_id=user.id,
        title=body.title,
    )
    return ThreadOut.model_validate(row)


@router.delete("/{thread_id}", response_model=ThreadOut)
async def delete_thread(thread_id: UUID, sb: SbUserDep, user: UserDep):
    row = await thread_service.archive_thread(sb, thread_id=thread_id, user_id=user.id)
    return ThreadOut.model_validate(row)
