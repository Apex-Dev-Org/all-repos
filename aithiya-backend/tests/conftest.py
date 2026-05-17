import os

import pytest


def _ensure_env() -> None:
    env = {
        "SUPABASE_URL": "http://localhost",
        "SUPABASE_ANON_KEY": "anon-test-key",
        "SUPABASE_SERVICE_ROLE_KEY": "service-test-key",
        "SUPABASE_JWT_AUDIENCE": "authenticated",
        "GEMINI_API_KEY": "dummy-gemini-key",
        "ENV": "test",
        "LOG_LEVEL": "WARNING",
        "CORS_ORIGINS": "http://localhost",
    }
    for k, v in env.items():
        os.environ.setdefault(k, v)


_ensure_env()


@pytest.fixture()
def client():
    from fastapi.testclient import TestClient

    from app.main import app

    return TestClient(app)
