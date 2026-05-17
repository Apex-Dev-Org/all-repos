import { NextResponse } from "next/server";
import {
  getSupabaseAuthConfig,
  missingSupabaseConfigResponse,
  readSupabaseJson,
  supabaseAuthHeaders,
  supabaseErrorMessage,
} from "../_supabase";

export async function POST(request: Request) {
  const { email, password } = await request.json();

  if (!email || !password) {
    return NextResponse.json(
      { error: "Email and password are required." },
      { status: 400 }
    );
  }

  const config = getSupabaseAuthConfig();
  if (!config) return missingSupabaseConfigResponse();

  const response = await fetch(
    `${config.url}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: supabaseAuthHeaders(config.anonKey),
      body: JSON.stringify({ email, password }),
    }
  );

  const data = await readSupabaseJson(response);

  if (!response.ok) {
    return NextResponse.json(
      { error: supabaseErrorMessage(data, "Invalid login details.") },
      { status: response.status }
    );
  }

  return NextResponse.json(data);
}
