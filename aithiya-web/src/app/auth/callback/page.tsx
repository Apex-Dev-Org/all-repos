"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ShieldCheck } from "lucide-react";
import { useTranslation } from "../../../i18n/useTranslation";
import { authService } from "../../../services/authService";
import type { SupabaseAuthPayload } from "../../../services/authSession";

export default function AuthCallbackPage() {
  const { t } = useTranslation();
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    async function finishGoogleLogin() {
      const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ""));
      const queryParams = new URLSearchParams(window.location.search);
      const providerError =
        hashParams.get("error_description") ??
        queryParams.get("error_description") ??
        hashParams.get("error") ??
        queryParams.get("error");

      if (providerError) {
        throw new Error(providerError);
      }

      const payload: SupabaseAuthPayload = {
        access_token:
          hashParams.get("access_token") ?? queryParams.get("access_token") ?? undefined,
        refresh_token:
          hashParams.get("refresh_token") ?? queryParams.get("refresh_token") ?? undefined,
        expires_in: parseNumber(hashParams.get("expires_in") ?? queryParams.get("expires_in")),
        expires_at: parseNumber(hashParams.get("expires_at") ?? queryParams.get("expires_at")),
      };

      await authService.completeOAuthSession(payload);

      const next = getSafeNextPath(queryParams.get("next")) ?? "/chat";
      window.history.replaceState(null, "", "/auth/callback");
      window.location.replace(next);
    }

    finishGoogleLogin().catch((cause) => {
      if (cancelled) return;
      console.error("Google sign-in callback failed", cause);
      setError(t("authError"));
    });

    return () => {
      cancelled = true;
    };
  }, [t]);

  return (
    <main className="callback-page">
      <section className="callback-card">
        <Link href="/" className="callback-logo">
          <img src="/aythiya_logo.png" alt={t("loginBrandTitle")} />
        </Link>

        <div className="callback-icon">
          <ShieldCheck size={28} />
        </div>

        <h1>{t("authAuthenticating")}</h1>
        <p>{error || t("authLoginSubtitle")}</p>

        {error && (
          <Link className="callback-action" href="/login">
            {t("signInButton")}
          </Link>
        )}
      </section>

      <style>{`
        .callback-page {
          min-height: 100vh;
          display: grid;
          place-items: center;
          padding: 28px;
          background: #f8fbff;
          color: #0f172a;
          font-family: Inter, sans-serif;
        }

        .callback-card {
          width: min(420px, 100%);
          padding: 34px;
          border-radius: 24px;
          background: #fff;
          border: 1px solid #e2e8f0;
          box-shadow: 0 22px 60px rgba(15,23,42,.1);
          text-align: center;
        }

        .callback-logo img {
          width: 124px;
          height: auto;
          margin-bottom: 18px;
        }

        .callback-icon {
          width: 58px;
          height: 58px;
          margin: 0 auto 18px;
          border-radius: 18px;
          display: grid;
          place-items: center;
          color: #1d4ed8;
          background: #eff6ff;
        }

        .callback-card h1 {
          font-size: 24px;
          margin: 0 0 8px;
        }

        .callback-card p {
          margin: 0;
          color: #64748b;
          font-size: 14px;
          line-height: 1.5;
        }

        .callback-action {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          min-height: 44px;
          margin-top: 22px;
          padding: 0 18px;
          border-radius: 12px;
          color: #fff;
          background: #1d4ed8;
          text-decoration: none;
          font-weight: 900;
        }
      `}</style>
    </main>
  );
}

function parseNumber(value: string | null) {
  if (!value) return undefined;

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function getSafeNextPath(next: string | null) {
  if (!next || !next.startsWith("/") || next.startsWith("//")) {
    return undefined;
  }

  return next;
}
