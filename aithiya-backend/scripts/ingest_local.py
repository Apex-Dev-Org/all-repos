import asyncio
from pathlib import Path
from typing import Annotated
from uuid import UUID

import typer

cli = typer.Typer(no_args_is_help=True)


@cli.command()
def run(
    pdf: Annotated[Path, typer.Argument(exists=True, readable=True)],
    admin_user_id: Annotated[UUID, typer.Option(..., help="UUID of admin profile inserting rows")],
    title_prefix: Annotated[str | None, typer.Option(help="Chunk title prefix")] = None,
):
    """Ingest a PDF into Supabase legal_documents using credentials from .env."""
    from google import genai

    from app.core.config import get_settings
    from app.infrastructure.db.supabase_client import create_service_supabase
    from app.infrastructure.ingestion.pipeline import ingest_pdf_file

    settings = get_settings()
    stem = pdf.stem
    prefix = (title_prefix or stem).strip() or "Legal document"

    async def _run():
        gemini_client = genai.Client(api_key=settings.gemini_api_key)
        svc = create_service_supabase(settings)
        summary = await ingest_pdf_file(
            pdf_path=pdf.resolve(),
            gemini_client=gemini_client,
            service_client=svc,
            settings=settings,
            admin_id=admin_user_id,
            title_prefix=prefix,
            extra_metadata={"source_file": pdf.name},
        )
        typer.echo(summary)

    asyncio.run(_run())


if __name__ == "__main__":
    cli()
