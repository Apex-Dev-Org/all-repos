from fastapi import APIRouter

from app.api.v1.routes import admin, chat, health, me, messages, threads

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(me.router)
api_router.include_router(threads.router)
api_router.include_router(messages.router)
api_router.include_router(chat.router)
api_router.include_router(admin.router)
