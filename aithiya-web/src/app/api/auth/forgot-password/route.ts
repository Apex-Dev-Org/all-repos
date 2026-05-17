import { NextResponse } from "next/server";
import {
  getSupabaseAuthConfig,
  getResetPasswordRedirectUrl,
  missingSupabaseConfigResponse,
  readSupabaseJson,
  supabaseAuthHeaders,
  supabaseErrorMessage,
} from "../_supabase";

export async function POST(request: Request) {
  const { email } = await request.json();

  if (!email) {
    return NextResponse.json(
      { error: "Email address is required." },
      { status: 400 }
    );
  }

  const config = getSupabaseAuthConfig();
  if (!config) return missingSupabaseConfigResponse();

  let redirectTo: string;
  try {
    redirectTo = getResetPasswordRedirectUrl(request);
  } catch {
    return NextResponse.json(
      { error: "Password reset redirect URL is not configured correctly." },
      { status: 500 }
    );
  }

  const response = await fetch(`${config.url}/auth/v1/recover`, {
    method: "POST",
    headers: supabaseAuthHeaders(config.anonKey),
    body: JSON.stringify({
      email,
      redirect_to: redirectTo,
    }),
  });

  const data = await readSupabaseJson(response);

  if (!response.ok) {
    return NextResponse.json(
      { error: supabaseErrorMessage(data, "Unable to send password reset email.") },
      { status: response.status }
    );
  }

  return NextResponse.json({
    message: "Password reset email sent. Please check your inbox.",
  });
}
