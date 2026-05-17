from collections.abc import AsyncIterator

from google import genai
from google.genai import types
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import Settings
from app.core.exceptions import UpstreamAIError


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=8))
async def generate_text(client: genai.Client, settings: Settings, *, system: str, user: str) -> str:
    try:
        resp = await client.aio.models.generate_content(
            model=settings.gemini_chat_model,
            contents=user,
            config=types.GenerateContentConfig(system_instruction=system, temperature=0.2),
        )
    except Exception as exc:
        raise UpstreamAIError("Gemini generation failed") from exc

    text = getattr(resp, "text", None)
    if not text:
        raise UpstreamAIError("Gemini returned empty body")
    return text


async def generate_text_stream(
    client: genai.Client, settings: Settings, *, system: str, user: str
) -> AsyncIterator[str]:
    try:
        stream_mgr = await client.aio.models.generate_content_stream(
            model=settings.gemini_chat_model,
            contents=user,
            config=types.GenerateContentConfig(system_instruction=system, temperature=0.2),
        )
    except Exception as exc:
        raise UpstreamAIError("Gemini streaming failed") from exc

    try:
        async for chunk in stream_mgr:
            piece = getattr(chunk, "text", None)
            if piece:
                yield piece
    except Exception as exc:
        raise UpstreamAIError("Gemini streaming interrupted") from exc
