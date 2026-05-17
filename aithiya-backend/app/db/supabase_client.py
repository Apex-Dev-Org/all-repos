from app.core.config import Settings
from supabase import Client, ClientOptions, create_client


def create_user_supabase(settings: Settings, bearer_jwt: str) -> Client:
    opts = ClientOptions(headers={"Authorization": f"Bearer {bearer_jwt}"})
    return create_client(settings.supabase_url, settings.supabase_anon_key, options=opts)


def create_service_supabase(settings: Settings) -> Client:
    return create_client(settings.supabase_url, settings.supabase_service_role_key)


def rpc_sync(client: Client, fn_name: str, params: dict) -> object:
    return client.rpc(fn_name, params).execute()
