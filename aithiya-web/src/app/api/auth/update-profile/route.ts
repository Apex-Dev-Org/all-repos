import { NextResponse } from "next/server";
import {
  getSupabaseAuthConfig,
  missingSupabaseConfigResponse,
  readSupabaseJson,
  supabaseAuthHeaders,
  supabaseErrorMessage,
} from "../_supabase";

export async function POST(request: Request) {
  const authHeader = request.headers.get("authorization");
  const token = authHeader?.match(/^Bearer\s+(.+)$/i)?.[1];

  if (!token) {
    return NextResponse.json({ error: "Authorization bearer token is required." }, { status: 401 });
  }

  const { name } = await request.json().catch(() => ({}));

  if (!name || typeof name !== "string" || !name.trim()) {
    return NextResponse.json({ error: "Name is required." }, { status: 400 });
  }

  const config = getSupabaseAuthConfig();
  if (!config) return missingSupabaseConfigResponse();

  const trimmed = name.trim();

  const response = await fetch(`${config.url}/auth/v1/user`, {
    method: "PUT",
    headers: supabaseAuthHeaders(config.anonKey, token),
    body: JSON.stringify({
      data: {
        name: trimmed,
        full_name: trimmed,
      },
    }),
  });

  const data = await readSupabaseJson(response);

  if (!response.ok) {
    return NextResponse.json(
      { error: supabaseErrorMessage(data, "Unable to update profile.") },
      { status: response.status }
    );
  }

  return NextResponse.json(data);
}
