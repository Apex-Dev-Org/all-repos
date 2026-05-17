# Aithiya Backend

FastAPI backend for Sri Lankan legal AI (RAG + Gemini).

## Local setup (Windows, Python 3.12)

```powershell
py -3.12 -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# Fill in SUPABASE_* and GEMINI_API_KEY (JWTs verified via Supabase JWKS; no JWT secret).

uvicorn app.main:app --reload
```

## Layout

- `app/api/` – HTTP routers, deps, middleware
- `app/application/` – use-cases (chat, ingestion, threads, …)
- `app/domain/` – core types (attachments, retrieval chunks)
- `app/infrastructure/` – Supabase, Gemini, ingestion, JWT
- `app/schemas/` – Pydantic API models

## Tuning prompts, guardrails, and citation labels

All prompts, safety patterns, refusal copy, and Act-citation metadata live under
`app/infrastructure/ai/prompts/` as editable text/JSON files — no code changes
required to adjust them.

- `prompts/templates/system/*.md` — the production system prompt is composed
  from these section files in lexical filename order (`00_identity.md`,
  `01_language.md`, …, `09_output.md`). Edit a section or add a new
  `XX_<topic>.md` and it is picked up on next process start.
- `prompts/templates/rag_user.md` — the user-turn skeleton with the
  `{{TURN_NOTE}} / {{ATTACHMENT_NOTE}} / {{CONTEXT}} / {{QUESTION}}` slots.
- `prompts/templates/safety/patterns.json` — preflight refusal regex patterns
  (one per category). Matched against the raw user query before any tokens
  are spent.
- `prompts/templates/safety/refusal.md` — user-facing refusal text returned
  when any pattern matches.
- `prompts/data/acts.json` — registry mapping internal ingest codes
  (e.g. `CIVIL-PROCEDURE-CODE`) to structured Act fields (`act_name`,
  `act_no`, `year`, `jurisdiction`). Whenever you ingest a new Act with a
  short `--title-prefix`, add an entry so user-facing citations render
  *"Civil Procedure Code, Act No. 2 of 1889"* instead of
  *"CIVIL-PROCEDURE-CODE"*. Lookup is case-insensitive and tolerates the
  `" · chunk N"` suffix appended at ingest time.

Cached loaders expose `reload_*()` helpers (`reload_prompts`,
`reload_safety`, `reload_registry`) for hot-editing without restarting.
