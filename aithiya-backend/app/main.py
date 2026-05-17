from fastapi import FastAPI

from app.api.middleware import configure_http
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.lifespan import lifespan


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="Aithiya Legal AI API", lifespan=lifespan)
    configure_http(app)
    app.include_router(api_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
