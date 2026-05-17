from google import genai
from google.genai import types
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import Settings
from app.core.exceptions import UpstreamAIError


def _vectors_from_embed_response(resp: object, expected: int) -> list[list[float]]:
    embeddings = getattr(resp, "embeddings", None)
    if embeddings:
        out: list[list[float]] = []
        for emb in embeddings:
            vals = getattr(emb, "values", None)
            if vals is None:
                continue
            out.append(list(map(float, vals)))
        if len(out) != expected:
            raise UpstreamAIError("Embedding count mismatch")
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


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=8))
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

    vecs = _vectors_from_embed_response(resp, len(texts))
    dim = settings.gemini_embed_output_dim
    for v in vecs:
        if len(v) != dim:
            raise UpstreamAIError("Unexpected embedding dimensionality")
    return vecs


async def embed_query(client: genai.Client, settings: Settings, text: str) -> list[float]:
    rows = await embed_batch(client, settings, [text])
    return rows[0]
