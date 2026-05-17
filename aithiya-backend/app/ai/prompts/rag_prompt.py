from app.ai.prompts import system_prompts
from app.core.constants import SupportedLanguage
from app.retrieval.reranker import RetrievedChunk


def answer_language_hint(lang: SupportedLanguage) -> str:
    mapping = {
        SupportedLanguage.EN: "English",
        SupportedLanguage.SI: "Sinhala",
        SupportedLanguage.TA: "Tamil",
        SupportedLanguage.MIXED: "the same language as the user question",
    }
    return mapping.get(lang, "English")


def build_context_blocks(chunks: list[RetrievedChunk]) -> str:
    blocks: list[str] = []
    for ch in chunks:
        blocks.append(f"DOC_ID:{ch.doc_id}\nTITLE:{ch.title}\nTEXT:\n{ch.content}")
    return "\n---\n".join(blocks)


def build_system_instruction(lang: SupportedLanguage) -> str:
    lk = lang.value
    key = lk if lk in {"en", "si", "ta"} else "en"
    return system_prompts.system_prompt_for(key)


def build_user_prompt(query: str, chunks: list[RetrievedChunk], lang: SupportedLanguage) -> str:
    tmpl = system_prompts.rag_user_skeleton()
    ctx = build_context_blocks(chunks)
    return (
        tmpl.replace("{{CONTEXT}}", ctx)
        .replace("{{QUESTION}}", query)
        .replace("{{ANSWER_LANGUAGE}}", answer_language_hint(lang))
    )
