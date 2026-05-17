"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { ArrowRight, Eye, EyeOff, Lock, ShieldCheck } from "lucide-react";
import { authService } from "../../services/authService";
import { useTranslation } from "../../i18n/useTranslation";

export default function ResetPasswordPage() {
  const { t } = useTranslation();
  const [accessToken, setAccessToken] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [form, setForm] = useState({
    password: "",
    confirmPassword: "",
  });

  useEffect(() => {
    let cancelled = false;
    queueMicrotask(() => {
      if (cancelled) return;

      const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ""));
      const queryParams = new URLSearchParams(window.location.search);
      const token =
        hashParams.get("access_token") ??
        queryParams.get("access_token") ??
        "";

      setAccessToken(token);

      if (!token) {
        setError(t("resetInvalidLink"));
      }
    });

    return () => {
      cancelled = true;
    };
  }, [t]);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError("");
    setSuccess("");

    if (!accessToken) {
      setError(t("resetInvalidLink"));
      return;
    }

    if (form.password.length < 8) {
      setError(t("resetMinLength"));
      return;
    }

    if (form.password !== form.confirmPassword) {
      setError(t("validatorPasswordsDontMatch"));
      return;
    }

    setLoading(true);
    try {
      await authService.updatePassword({
        accessToken,
        password: form.password,
      });
      setSuccess(t("resetUpdated"));
      window.history.replaceState(null, "", "/reset-password");
    } catch {
      setError(t("resetUnableUpdate"));
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="reset-page">
      <section className="reset-card">
        <Link href="/" className="reset-logo">
          <img src="/aythiya_logo.png" alt={t("loginBrandTitle")} />
        </Link>

        <div className="reset-icon">
          <ShieldCheck size={28} />
        </div>

        <div className="reset-heading">
          <h1>{t("resetPageTitle")}</h1>
          <p>{t("resetPageSubtitle")}</p>
        </div>

        <form onSubmit={submit}>
          <ResetField
            label={t("resetNewPasswordLabel")}
            value={form.password}
            type={showPassword ? "text" : "password"}
            onChange={(value) => setForm((prev) => ({ ...prev, password: value }))}
            rightIcon={
              <button
                type="button"
                onClick={() => setShowPassword((prev) => !prev)}
                aria-label={showPassword ? t("authHidePassword") : t("authShowPassword")}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            }
          />

          <ResetField
            label={t("resetConfirmNewPasswordLabel")}
            value={form.confirmPassword}
            type="password"
            onChange={(value) =>
              setForm((prev) => ({ ...prev, confirmPassword: value }))
            }
          />

          {error && <p className="reset-error">{error}</p>}
          {success && <p className="reset-success">{success}</p>}

          <button className="reset-submit" type="submit" disabled={loading || !accessToken}>
            {loading ? t("resetUpdating") : t("resetUpdate")}
            <ArrowRight size={18} />
          </button>
        </form>

        <p className="reset-bottom">
          {t("resetBackToSignIn")}{" "}
          <Link href="/login">{t("signInButton")}</Link>
        </p>
      </section>

      <style>{`
        .reset-page {
          min-height: 100vh;
          display: grid;
          place-items: center;
          padding: 28px;
          color: #0f172a;
          background:
            radial-gradient(circle at top left, rgba(191,219,254,.5), transparent 32%),
            linear-gradient(180deg, #fff 0%, #f8fbff 100%);
        }

        .reset-card {
          width: min(440px, 100%);
          padding: 36px;
          border-radius: 30px;
          background: rgba(255,255,255,.94);
          border: 1px solid #e2e8f0;
          box-shadow: 0 24px 70px rgba(15,23,42,.12);
          animation: resetReveal .75s ease both;
        }

        .reset-logo {
          display: flex;
          justify-content: center;
          margin-bottom: 20px;
        }

        .reset-logo img {
          width: 130px;
          height: auto;
        }

        .reset-icon {
          width: 58px;
          height: 58px;
          display: grid;
          place-items: center;
          margin: 0 auto 18px;
          border-radius: 18px;
          color: #fff;
          background: linear-gradient(135deg, #1d4ed8, #60a5fa);
          box-shadow: 0 16px 32px rgba(29,78,216,.22);
        }

        .reset-heading {
          text-align: center;
          margin-bottom: 24px;
        }

        .reset-heading h1 {
          font-size: 28px;
          margin: 0 0 8px;
          letter-spacing: -.03em;
        }

        .reset-heading p {
          margin: 0;
          color: #64748b;
          line-height: 1.6;
          font-size: 14px;
        }

        .reset-field {
          margin-bottom: 14px;
        }

        .reset-field label {
          display: block;
          color: #475569;
          font-size: 11px;
          font-weight: 900;
          letter-spacing: .12em;
          text-transform: uppercase;
          margin-bottom: 7px;
        }

        .reset-box {
          display: flex;
          align-items: center;
          gap: 10px;
          height: 48px;
          padding: 0 14px;
          border-radius: 14px;
          background: rgba(248,250,252,.95);
          border: 1px solid rgba(226,232,240,.95);
          transition: border-color .2s, box-shadow .2s, background .2s;
        }

        .reset-box:focus-within {
          border-color: #93c5fd;
          background: #fff;
          box-shadow: 0 0 0 4px rgba(147,197,253,.22);
        }

        .reset-box svg {
          color: #94a3b8;
        }

        .reset-box input {
          min-width: 0;
          flex: 1;
          border: 0;
          outline: 0;
          background: transparent;
          color: #0f172a;
          font: inherit;
          font-size: 14px;
        }

        .reset-box button {
          border: 0;
          background: transparent;
          color: #94a3b8;
          cursor: pointer;
          display: grid;
          place-items: center;
        }

        .reset-error,
        .reset-success {
          padding: 9px 12px;
          border-radius: 12px;
          font-size: 13px;
          line-height: 1.5;
          margin-bottom: 12px;
        }

        .reset-error {
          color: #dc2626;
          background: #fef2f2;
          border: 1px solid #fecaca;
        }

        .reset-success {
          color: #166534;
          background: #f0fdf4;
          border: 1px solid #bbf7d0;
        }

        .reset-submit {
          width: 100%;
          height: 48px;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 9px;
          border: 0;
          border-radius: 14px;
          color: #fff;
          background: linear-gradient(135deg, #1d4ed8, #3b82f6);
          box-shadow: 0 14px 30px rgba(29,78,216,.24);
          font-weight: 900;
          cursor: pointer;
          transition: transform .2s, box-shadow .2s;
        }

        .reset-submit:hover {
          transform: translateY(-2px);
          box-shadow: 0 18px 40px rgba(29,78,216,.32);
        }

        .reset-submit:disabled {
          opacity: .7;
          cursor: not-allowed;
          transform: none;
        }

        .reset-bottom {
          text-align: center;
          color: #94a3b8;
          font-size: 13px;
          margin: 18px 0 0;
        }

        .reset-bottom a {
          color: #1d4ed8;
          font-weight: 900;
          text-decoration: none;
        }

        @keyframes resetReveal {
          from { opacity: 0; transform: translateY(18px); filter: blur(5px); }
          to { opacity: 1; transform: translateY(0); filter: blur(0); }
        }

        @media(max-width: 560px) {
          .reset-page { padding: 0; }
          .reset-card { min-height: 100vh; border-radius: 0; padding: 32px 20px; }
        }
      `}</style>
    </main>
  );
}

function ResetField({
  label,
  value,
  type,
  rightIcon,
  onChange,
}: {
  label: string;
  value: string;
  type: string;
  rightIcon?: React.ReactNode;
  onChange: (value: string) => void;
}) {
  return (
    <div className="reset-field">
      <label>{label}</label>
      <div className="reset-box">
        <Lock size={17} />
        <input
          value={value}
          type={type}
          placeholder="••••••••"
          onChange={(event) => onChange(event.target.value)}
        />
        {rightIcon}
      </div>
    </div>
  );
}
