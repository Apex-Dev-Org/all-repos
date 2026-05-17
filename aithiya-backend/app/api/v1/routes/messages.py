from uuid import UUID

from fastapi import APIRouter, Query

from app.api.deps import SbUserDep, UserDep
from app.application import thread_service
from app.infrastructure.db.repositories import messages_repo
from app.schemas.message import ChatMessageRow, MessageList

router = APIRouter(prefix="/threads/{thread_id}/messages", tags=["messages"])


@router.get("", response_model=MessageList)
async def list_messages(
    thread_id: UUID,
    sb: SbUserDep,
    user: UserDep,
    limit: int = Query(200, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    await thread_service.require_owned(sb, thread_id=thread_id, user_id=user.id)
    rows = await messages_repo.list_messages(
        sb,
        thread_id=thread_id,
        user_id=user.id,
        limit=limit,
        offset=offset,
    )
    items = [ChatMessageRow.model_validate(r) for r in rows]
    return MessageList(items=items)
