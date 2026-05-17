# Codex Instructions

- Never read, print, grep, cat, sed, awk, parse, or otherwise inspect `.env` or `.env.*` files unless the user explicitly asks for that in the same turn.
- Do not include `.env` or `.env.*` files in broad searches, diagnostics, or file listings.
- If real environment values are needed, ask the user to confirm the relevant value manually instead of opening secret files.
- Prefer code, README text, and non-secret configuration references when reasoning about required environment variables.
