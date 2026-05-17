from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    env: str = Field(default="local", alias="ENV")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    api_v1_prefix: str = Field(default="/api/v1", alias="API_V1_PREFIX")

    cors_origins: str = Field(
        default="http://localhost:5173",
        alias="CORS_ORIGINS",
    )

    supabase_url: str = Field(alias="SUPABASE_URL")
    supabase_anon_key: str = Field(alias="SUPABASE_ANON_KEY")
    supabase_service_role_key: str = Field(alias="SUPABASE_SERVICE_ROLE_KEY")
    supabase_jwt_audience: str = Field(default="authenticated", alias="SUPABASE_JWT_AUDIENCE")

    gemini_api_key: str = Field(alias="GEMINI_API_KEY")
    gemini_chat_model: str = Field(default="gemini-2.5-flash", alias="GEMINI_CHAT_MODEL")
    gemini_embed_model: str = Field(default="gemini-embedding-001", alias="GEMINI_EMBED_MODEL")
    gemini_embed_output_dim: int = Field(default=768, alias="GEMINI_EMBED_OUTPUT_DIM")

    rag_top_k: int = Field(default=8, ge=1, le=50, alias="RAG_TOP_K")
    rag_only_in_effect: bool = Field(default=True, alias="RAG_ONLY_IN_EFFECT")
    chunk_max_tokens: int = Field(default=800, alias="CHUNK_MAX_TOKENS")
    chunk_overlap_chars: int = Field(default=480, alias="CHUNK_OVERLAP_CHARS")
    embed_batch_size: int = Field(default=16, ge=1, le=256, alias="EMBED_BATCH_SIZE")
    embed_batch_delay_s: float = Field(default=13.0, ge=0.0, alias="EMBED_BATCH_DELAY_S")
    embed_quota_retry_max: int = Field(default=2, ge=0, alias="EMBED_QUOTA_RETRY_MAX")
    embed_quota_retry_wait_s: float = Field(default=60.0, ge=1.0, alias="EMBED_QUOTA_RETRY_WAIT_S")

    temp_dir: str = Field(default="./data/temp", alias="TEMP_DIR")
    max_upload_mb: int = Field(default=25, alias="MAX_UPLOAD_MB")
    max_chat_total_mb: int = Field(default=50, alias="MAX_CHAT_TOTAL_MB")

    rate_limit_chat_per_minute: int = Field(default=60, alias="RATE_LIMIT_CHAT_PER_MINUTE")
    rate_limit_ingest_per_minute: int = Field(default=10, alias="RATE_LIMIT_INGEST_PER_MINUTE")

    admin_role_cache_ttl_s: float = Field(default=60.0)

    chat_history_turns: int = Field(default=10, ge=0, le=40, alias="CHAT_HISTORY_TURNS")
    enable_web_grounding: bool = Field(default=True, alias="ENABLE_WEB_GROUNDING")
    web_grounding_keywords: str = Field(
        default=(
            "phone,phone number,contact,contact number,hotline,helpline,address,"
            "office,office hours,call,email,reach,where is,location,"
            "\u0daf\u0dd4\u0dbb\u0d9a\u0dad\u0db1,\u0d87\u0db8\u0dad\u0dd4\u0db8,"
            "\u0dc0\u0dd2\u0db8\u0dc3\u0dd3\u0db8,\u0d9a\u0dcf\u0dbb\u0dca\u0dba\u0dcf\u0dbd\u0dba,"
            "\u0bb5\u0bbf\u0bb2\u0bbe\u0b9a\u0bae\u0bcd,\u0ba4\u0bca\u0b9f\u0bb0\u0bcd\u0baa\u0bc1,"
            "\u0ba4\u0bca\u0bb2\u0bc8\u0baa\u0bc7\u0b9a\u0bbf,\u0b89\u0ba4\u0bb5\u0bbf,"
            "\u0b85\u0bb2\u0bc1\u0bb5\u0bb2\u0b95\u0bae\u0bcd"
        ),
        alias="WEB_GROUNDING_KEYWORDS",
    )

    @property
    def supabase_jwks_url(self) -> str:
        return f"{self.supabase_url.rstrip('/')}/auth/v1/.well-known/jwks.json"


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
