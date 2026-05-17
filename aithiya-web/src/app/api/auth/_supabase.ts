import { NextResponse } from "next/server";

type SupabaseAuthConfig = {
  url: string;
  anonKey: string;
};

export function normalizeHttpUrl(raw: string) {
  const withProtocol = /^[a-z][a-z\d+.-]*:\/\//i.test(raw) ? raw : `https://${raw}`;
  const parsed = new URL(withProtocol);

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("URL must use http or https.");
  }

  parsed.pathname = parsed.pathname.replace(/\/+$/, "");
  parsed.search = "";
  parsed.hash = "";
  return parsed.toString().replace(/\/+$/, "");
}

export function getRequestOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (origin) return origin;

  const host = request.headers.get("x-forwarded-host") ?? request.headers.get("host");
  if (!host) return undefined;

  const protocol = request.headers.get("x-forwarded-proto") ?? "http";
  return `${protocol}://${host}`;
}

export function getSupabaseAuthConfig(): SupabaseAuthConfig | undefined {
  const rawUrl = (process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL)?.trim();
  const anonKey = (
    process.env.SUPABASE_ANON_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  )?.trim();

  if (!rawUrl || !anonKey) return undefined;

  try {
    return { url: normalizeHttpUrl(rawUrl), anonKey };
  } catch {
    return undefined;
  }
}

export function missingSupabaseConfigResponse() {
  return NextResponse.json(
    { error: "Supabase auth is not configured." },
    { status: 500 }
  );
}

export function supabaseAuthHeaders(anonKey: string, bearerToken = anonKey) {
  return {
    apikey: anonKey,
    Authorization: `Bearer ${bearerToken}`,
    "Content-Type": "application/json",
  };
}

export function getResetPasswordRedirectUrl(request: Request) {
  const rawOrigin =
    getRequestOrigin(request) ??
    process.env.NEXT_PUBLIC_APP_URL?.trim() ??
    "http://localhost:3000";

  const origin = normalizeHttpUrl(rawOrigin);
  return `${origin}/reset-password`;
}

export async function readSupabaseJson(response: Response) {
  return response.json().catch(() => ({}));
}

export function supabaseErrorMessage(data: unknown, fallback: string) {
  if (typeof data !== "object" || data === null) return fallback;
  const record = data as Record<string, unknown>;

  return String(
    record.error_description ??
      record.msg ??
      record.message ??
      record.error ??
      fallback
  );
}
