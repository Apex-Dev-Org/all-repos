import { NextResponse } from "next/server";
import {
  getRequestOrigin,
  getSupabaseAuthConfig,
  missingSupabaseConfigResponse,
  normalizeHttpUrl,
} from "../_supabase";

const DEFAULT_REDIRECT_PATH = "/chat";

export async function GET(request: Request) {
  const config = getSupabaseAuthConfig();
  if (!config) return missingSupabaseConfigResponse();

  const requestUrl = new URL(request.url);
  const next = getSafeNextPath(requestUrl.searchParams.get("next")) ?? DEFAULT_REDIRECT_PATH;
  const rawOrigin =
    getRequestOrigin(request) ??
    process.env.NEXT_PUBLIC_APP_URL?.trim() ??
    "http://localhost:3000";
  const origin = normalizeHttpUrl(rawOrigin);

  const callbackUrl = new URL("/auth/callback", origin);
  callbackUrl.searchParams.set("next", next);

  const authorizeUrl = new URL(`${config.url}/auth/v1/authorize`);
  authorizeUrl.searchParams.set("provider", "google");
  authorizeUrl.searchParams.set("redirect_to", callbackUrl.toString());

  return NextResponse.redirect(authorizeUrl);
}

function getSafeNextPath(next: string | null) {
  if (!next || !next.startsWith("/") || next.startsWith("//")) {
    return undefined;
  }

  return next;
}
