import { NextResponse } from "next/server";
import {
  getSupabaseAuthConfig,
  missingSupabaseConfigResponse,
  readSupabaseJson,
  supabaseAuthHeaders,
  supabaseErrorMessage,
} from "../_supabase";

export async function POST(request: Request) {
  const { accessToken, password } = await request.json();

  if (!accessToken || !password) {
    return NextResponse.json(
      { error: "Reset token and new password are required." },
      { status: 400 }
    );
  }

  if (password.length < 8) {
    return NextResponse.json(
      { error: "Password must be at least 8 characters." },
      { status: 400 }
    );
  }

  const config = getSupabaseAuthConfig();
  if (!config) return missingSupabaseConfigResponse();

  const response = await fetch(`${config.url}/auth/v1/user`, {
    method: "PUT",
    headers: supabaseAuthHeaders(config.anonKey, accessToken),
    body: JSON.stringify({ password }),
  });

  const data = await readSupabaseJson(response);

  if (!response.ok) {
    return NextResponse.json(
      {
        error: supabaseErrorMessage(
          data,
          "Unable to update password. Please request a new reset link."
        ),
      },
      { status: response.status }
    );
  }

  return NextResponse.json({
    message: "Password updated successfully.",
  });
}
