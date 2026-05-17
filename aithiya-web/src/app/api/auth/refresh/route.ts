import { NextResponse } from "next/server";
import {
  getSupabaseAuthConfig,
  missingSupabaseConfigResponse,
  readSupabaseJson,
  supabaseAuthHeaders,
  supabaseErrorMessage,
} from "../_supabase";

export async function POST(request: Request) {
  const { refreshToken } = await request.json().catch(() => ({}));

  if (!refreshToken || typeof refreshToken !== "string") {
    return NextResponse.json(
      { error: "Refresh token is required." },
      { status: 400 }
    );
  }

  const config = getSupabaseAuthConfig();
  if (!config) return missingSupabaseConfigResponse();

  const response = await fetch(`${config.url}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: supabaseAuthHeaders(config.anonKey),
    body: JSON.stringify({ refresh_token: refreshToken }),
  });

  const data = await readSupabaseJson(response);

  if (!response.ok) {
    return NextResponse.json(
      { error: supabaseErrorMessage(data, "Could not refresh Supabase session.") },
      { status: response.status }
    );
  }

  return NextResponse.json(data);
}
