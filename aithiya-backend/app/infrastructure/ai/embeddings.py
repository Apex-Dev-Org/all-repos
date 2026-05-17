import asyncio

from google import genai
from google.genai import errors as genai_errors
from google.genai import types
from tenacity import retry, retry_if_exception, stop_after_attempt, wait_exponential

from app.core.config import Settings
from app.core.exceptions import EmbedQuotaError, UpstreamAIError
from app.core.logging import log


def _vectors_from_embed_response(resp: object, texts: list[str]) -> list[list[float]]:
    expected = len(texts)
    embeddings = getattr(resp, "embeddings", None)
    if embeddings:
        out: list[list[float]] = []
        for emb in embeddings:
            vals = getattr(emb, "values", None)
            if vals is None:
                continue
            out.append(list(map(float, vals)))
        if len(out) != expected:
            log().warning(
                "embed_count_mismatch",
                expected=expected,
                got=len(out),
                text_lengths=[len(t) for t in texts],
                first_chars=[t[:80] for t in texts],
            )
            raise UpstreamAIError(
                f"Embedding count mismatch: got {len(out)}, expected {expected}"
            )
        return out

    single = getattr(resp, "embedding", None)
    if single is not None:
        vals = getattr(single, "values", None)
        if vals is None:
            raise UpstreamAIError("Malformed embedding payload")
        v = list(map(float, vals))
        if expected != 1:
            raise UpstreamAIError("Embedding batch expected")
        return [v]

    raise UpstreamAIError("No embeddings in Gemini response")


def _is_quota_error(exc: BaseException | None) -> bool:
    if not isinstance(exc, genai_errors.ClientError):
        return False
    return getattr(exc, "status_code", None) == 429 or getattr(exc, "code", None) == 429


def _retry_unless_quota(exc: BaseException) -> bool:
    # Skip inner retries on 429 so we don't burn additional RPM against the
    # same per-minute cap; the outer wrapper does the long wait instead.
    if isinstance(exc, UpstreamAIError) and _is_quota_error(exc.__cause__):
        return False
    return isinstance(exc, Exception)


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=8),
    retry=retry_if_exception(_retry_unless_quota),
    reraise=True,
)
async def embed_batch(
    client: genai.Client,
    settings: Settings,
    texts: list[str],
) -> list[list[float]]:
    if not texts:
        return []

    cfg = types.EmbedContentConfig(output_dimensionality=settings.gemini_embed_output_dim)

    try:
        resp = await client.aio.models.embed_content(
            model=settings.gemini_embed_model,
            contents=texts,
            config=cfg,
        )
    except Exception as exc:
        raise UpstreamAIError("Gemini embeddings request failed") from exc

    vecs = _vectors_from_embed_response(resp, texts)
    dim = settings.gemini_embed_output_dim
    for v in vecs:
        if len(v) != dim:
            raise UpstreamAIError("Unexpected embedding dimensionality")
    return vecs


async def embed_batch_with_quota_handling(
    client: genai.Client,
    settings: Settings,
    texts: list[str],
) -> list[list[float]]:
    """Wrap embed_batch with long-wait retries for Gemini 429 quota errors.

    Transient/network errors are already retried inside embed_batch via tenacity
    with short exponential backoff. That backoff is too short to outwait a
    per-minute quota cap, so on 429 we sleep `embed_quota_retry_wait_s` and try
    again, up to `embed_quota_retry_max` extra attempts. On final failure we
    raise EmbedQuotaError so the pipeline can save partial progress instead of
    crashing.
    """
    max_attempts = settings.embed_quota_retry_max + 1
    for attempt in range(max_attempts):
        try:
            return await embed_batch(client, settings, texts)
        except UpstreamAIError as exc:
            if not _is_quota_error(exc.__cause__):
                raise
            if attempt >= max_attempts - 1:
                raise EmbedQuotaError("Gemini embedding quota exhausted") from exc.__cause__
            await asyncio.sleep(settings.embed_quota_retry_wait_s)

    raise EmbedQuotaError("Gemini embedding quota exhausted")


async def embed_query(client: genai.Client, settings: Settings, text: str) -> list[float]:
    rows = await embed_batch(client, settings, [text])
    return rows[0]
