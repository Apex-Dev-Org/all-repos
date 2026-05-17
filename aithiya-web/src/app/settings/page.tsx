"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  ArrowLeft,
  CreditCard,
  Lock,
  Pencil,
  RefreshCw,
  Sparkles,
  User,
} from "lucide-react";
import { authService } from "../../services/authService";
import { getValidAccessToken } from "../../services/authSession";
import { useTranslation } from "../../i18n/useTranslation";

type BillingStatus = {
  plan: "free" | "pro" | "ultra";
  status: string | null;
  cycle: "monthly" | "yearly" | null;
  current_period_end: string | null;
  cancel_at_next_billing_date: boolean;
  has_billing_customer: boolean;
};

const DEFAULT_BILLING_STATUS: BillingStatus = {
  plan: "free",
  status: null,
  cycle: null,
  current_period_end: null,
  cancel_at_next_billing_date: false,
  has_billing_customer: false,
};

export default function SettingsPage() {
  const { t, locale, setLocale } = useTranslation();
  const router = useRouter();
  const [user, setUser] = useState(authService.getUser());
  const [busy, setBusy] = useState(false);
  const [billingBusy, setBillingBusy] = useState(false);
  const [billingLoading, setBillingLoading] = useState(false);
  const [billing, setBilling] = useState<BillingStatus>(DEFAULT_BILLING_STATUS);
  const [toast, setToast] = useState("");

  const [nameOpen, setNameOpen] = useState(false);
  const [nameDraft, setNameDraft] = useState(user?.name ?? "");

  const [resetOpen, setResetOpen] = useState(false);
  const [resetEmail, setResetEmail] = useState(user?.email ?? "");

  useEffect(() => {
    if (!authService.isAuthenticated()) {
      router.replace("/login");
    }
  }, [router]);

  const loadBillingStatus = async () => {
    setBillingLoading(true);
    setToast("");
    try {
      const token = await getValidAccessToken();
      if (!token) {
        router.replace("/login");
        return;
      }

      const response = await fetch("/api/billing/status", {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      const data = (await response.json().catch(() => ({}))) as
        | Partial<BillingStatus>
        | { error?: string };

      if (!response.ok) {
        throw new Error(
          "error" in data && data.error
            ? data.error
            : "Could not load billing status.",
        );
      }

      setBilling({
        ...DEFAULT_BILLING_STATUS,
        ...(data as Partial<BillingStatus>),
      });
    } catch (error) {
      setToast(
        error instanceof Error
          ? error.message
          : "Could not load billing status.",
      );
    } finally {
      setBillingLoading(false);
    }
  };

  useEffect(() => {
    let cancelled = false;
    queueMicrotask(() => {
      if (cancelled) return;

      const storedUser = authService.getUser();
      setUser(storedUser);
      setNameDraft(storedUser?.name ?? "");
      setResetEmail(storedUser?.email ?? "");
    });

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (authService.isAuthenticated()) {
      queueMicrotask(() => {
        void loadBillingStatus();
      });
    }
    // Run once on page entry; billing can be manually refreshed after checkout.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const displayName =
    user?.name?.trim() || user?.email || t("accountSignedInFallback");

  const saveName = async (event: FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setToast("");
    try {
      await authService.updateDisplayName(nameDraft.trim());
      setUser(authService.getUser());
      setToast(t("settingsSavedName"));
      setNameOpen(false);
    } catch {
      setToast(t("settingsCannotSaveName"));
    } finally {
      setBusy(false);
    }
  };

  const sendReset = async (event: FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setToast("");
    try {
      await authService.requestPasswordReset({ email: resetEmail.trim() });
      setToast(t("loginForgotPasswordSent"));
      setResetOpen(false);
    } catch {
      setToast(t("authResetFailed"));
    } finally {
      setBusy(false);
    }
  };

  const onSignOut = () => {
    authService.signOut();
    router.replace("/login");
  };

  const openBillingPortal = async () => {
    if (!billing.has_billing_customer) {
      setToast("Upgrade to a paid plan first to create your billing profile.");
      return;
    }

    setBillingBusy(true);
    setToast("");

    try {
      const token = await getValidAccessToken();
      if (!token) {
        router.replace("/login");
        return;
      }

      const response = await fetch("/customer-portal?send_email=false", {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      const data = (await response.json().catch(() => ({}))) as {
        error?: string;
        portal_url?: string;
      };

      if (!response.ok) {
        throw new Error(data.error ?? "Could not open billing portal.");
      }

      if (!data.portal_url) {
        throw new Error("Billing portal URL was not returned.");
      }

      window.location.href = data.portal_url;
    } catch (error) {
      setToast(
        error instanceof Error
          ? error.message
          : "Could not open billing portal.",
      );
    } finally {
      setBillingBusy(false);
    }
  };

  const planLabel = formatPlanLabel(billing.plan);
  const statusLabel = formatStatusLabel(billing.status, billing.plan);
  const renewsAt = formatDate(billing.current_period_end);
  const isPaid = billing.plan !== "free" && billing.status === "active";

  return (
    <main className="settings-page">
      <div className="settings-card">
        <header className="settings-header">
          <Link href="/chat" className="back">
            <ArrowLeft size={18} />
            {t("settingsBack")}
          </Link>
          <h1>{t("settingsTitle")}</h1>
        </header>

        {toast && <div className="toast">{toast}</div>}

        <section className="profile">
          <div className="avatar">
            <User size={32} />
          </div>
          <div className="profile-text">
            <h2>{displayName}</h2>
            {user?.email && <p>{user.email}</p>}
          </div>
        </section>

        <div className="actions">
          <button
            type="button"
            className="btn secondary"
            disabled={busy}
            onClick={() => setNameOpen(true)}
          >
            <Pencil size={16} />
            {t("settingsEditProfileDialogTitle")}
          </button>
          <button
            type="button"
            className="btn secondary"
            disabled={busy}
            onClick={() => setResetOpen(true)}
          >
            <Lock size={16} />
            {t("settingsResetPassword")}
          </button>
        </div>

        <section className="section">
          <h3>{t("settingsLanguageSection")}</h3>
          <div className="pills">
            <button
              type="button"
              className={locale === "si" ? "pill active" : "pill"}
              onClick={() => setLocale("si")}
            >
              {t("languageSinhala")}
            </button>
            <button
              type="button"
              className={locale === "en" ? "pill active" : "pill"}
              onClick={() => setLocale("en")}
            >
              {t("languageEnglish")}
            </button>
          </div>
        </section>

        <section className="section billing-section">
          <div className="section-heading">
            <h3>Billing</h3>
            <button
              type="button"
              className="icon-btn"
              disabled={billingLoading}
              onClick={loadBillingStatus}
              aria-label="Refresh billing status"
            >
              <RefreshCw size={15} />
            </button>
          </div>

          <div className="billing-card">
            <div>
              <p className="eyebrow">Current plan</p>
              <h2>{planLabel}</h2>
              <p className="muted">
                {billingLoading
                  ? "Checking your billing status..."
                  : billing.plan === "free"
                    ? "Upgrade when you need document analysis, higher limits, or premium features."
                    : billing.cancel_at_next_billing_date
                      ? "Your plan is active until the end of the current billing period."
                      : "Your plan is synced from Dodo after checkout is confirmed."}
              </p>
            </div>
            <span className={isPaid ? "status-pill active" : "status-pill"}>
              {statusLabel}
            </span>
          </div>

          <div className="billing-details">
            <div>
              <span>Billing cycle</span>
              <strong>{billing.cycle ? capitalize(billing.cycle) : "None"}</strong>
            </div>
            <div>
              <span>Next renewal</span>
              <strong>
                {billing.cancel_at_next_billing_date
                  ? "Cancels at period end"
                  : renewsAt}
              </strong>
            </div>
          </div>

          <div className="actions billing-actions">
            <Link href="/#pricing" className="btn secondary">
              <Sparkles size={16} />
              {billing.plan === "free" ? "View plans" : "Change plan"}
            </Link>
            <button
              type="button"
              className="btn primary"
              disabled={busy || billingBusy || !billing.has_billing_customer}
              onClick={openBillingPortal}
            >
              <CreditCard size={16} />
              {billingBusy ? "Opening..." : "Manage billing"}
            </button>
          </div>

          {!billing.has_billing_customer && (
            <p className="billing-note">
              The billing portal becomes available after your first successful
              paid checkout. If you just paid, wait a few seconds and refresh.
            </p>
          )}
        </section>

        <button
          type="button"
          className="btn danger"
          disabled={busy}
          onClick={onSignOut}
        >
          {t("settingsSignOut")}
        </button>
      </div>

      {nameOpen && (
        <div
          className="modal-backdrop"
          role="presentation"
          onClick={() => !busy && setNameOpen(false)}
        >
          <div
            className="modal"
            role="dialog"
            onClick={(e) => e.stopPropagation()}
          >
            <h3>{t("settingsEditProfileDialogTitle")}</h3>
            <p className="muted">{t("settingsEditNameSubtitle")}</p>
            <form onSubmit={saveName}>
              <label className="field">
                <span>{t("fieldLabelFullName")}</span>
                <input
                  value={nameDraft}
                  onChange={(e) => setNameDraft(e.target.value)}
                  placeholder={t("displayNameOptionalLabel")}
                  autoFocus
                />
              </label>
              <div className="modal-actions">
                <button
                  type="button"
                  className="btn ghost"
                  disabled={busy}
                  onClick={() => setNameOpen(false)}
                >
                  {t("dialogCancel")}
                </button>
                <button type="submit" className="btn primary" disabled={busy}>
                  {t("dialogSave")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {resetOpen && (
        <div
          className="modal-backdrop"
          role="presentation"
          onClick={() => !busy && setResetOpen(false)}
        >
          <div
            className="modal"
            role="dialog"
            onClick={(e) => e.stopPropagation()}
          >
            <h3>{t("loginForgotPasswordDialogTitle")}</h3>
            <p className="muted">{t("settingsResetPasswordDialogSubtitle")}</p>
            <form onSubmit={sendReset}>
              <label className="field">
                <span>{t("fieldLabelEmailAddress")}</span>
                <input
                  type="email"
                  value={resetEmail}
                  onChange={(e) => setResetEmail(e.target.value)}
                  required
                />
              </label>
              <div className="modal-actions">
                <button
                  type="button"
                  className="btn ghost"
                  disabled={busy}
                  onClick={() => setResetOpen(false)}
                >
                  {t("dialogCancel")}
                </button>
                <button type="submit" className="btn primary" disabled={busy}>
                  {t("dialogSend")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <style>{`
        .settings-page {
          min-height: 100vh;
          display: grid;
          place-items: center;
          padding: 28px;
          background: radial-gradient(circle at top left, rgba(191,219,254,.45), transparent 32%),
            linear-gradient(180deg, #fff 0%, #f8fbff 100%);
          color: #0f172a;
          font-family: Inter, system-ui, sans-serif;
        }
        .settings-card {
          width: min(520px, 100%);
          background: rgba(255,255,255,.94);
          border: 1px solid #e2e8f0;
          border-radius: 24px;
          padding: 28px;
          box-shadow: 0 24px 70px rgba(15,23,42,.1);
        }
        .settings-header {
          display: grid;
          gap: 10px;
          margin-bottom: 18px;
        }
        .settings-header h1 {
          margin: 0;
          font-size: 24px;
        }
        .back {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          color: #1d4ed8;
          font-weight: 800;
          text-decoration: none;
          font-size: 14px;
        }
        .toast {
          margin-bottom: 14px;
          padding: 10px 12px;
          border-radius: 12px;
          background: #eff6ff;
          border: 1px solid #bfdbfe;
          color: #1e40af;
          font-size: 13px;
          font-weight: 700;
        }
        .profile {
          display: flex;
          gap: 16px;
          align-items: center;
          padding: 16px;
          border-radius: 18px;
          background: rgba(239,246,255,.72);
          border: 1px solid rgba(191,219,254,.74);
          margin-bottom: 18px;
        }
        .avatar {
          width: 72px;
          height: 72px;
          border-radius: 999px;
          display: grid;
          place-items: center;
          background: #fff;
          border: 1px solid #e2e8f0;
          color: #64748b;
        }
        .profile-text h2 {
          margin: 0 0 4px;
          font-size: 18px;
        }
        .profile-text p {
          margin: 0;
          color: #64748b;
          font-size: 13px;
          word-break: break-word;
        }
        .actions {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 10px;
          margin-bottom: 22px;
        }
        .section h3 {
          margin: 0 0 10px;
          font-size: 15px;
        }
        .section-heading {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 12px;
        }
        .icon-btn {
          width: 34px;
          height: 34px;
          display: grid;
          place-items: center;
          border-radius: 12px;
          border: 1px solid #dbeafe;
          color: #1d4ed8;
          background: #eff6ff;
          cursor: pointer;
        }
        .icon-btn:disabled {
          opacity: .6;
          cursor: not-allowed;
        }
        .billing-section {
          margin-bottom: 22px;
        }
        .billing-card {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 14px;
          padding: 16px;
          border-radius: 18px;
          background: rgba(248,250,252,.9);
          border: 1px solid rgba(226,232,240,.95);
          margin-bottom: 10px;
        }
        .billing-card h2 {
          margin: 3px 0 6px;
          font-size: 24px;
        }
        .eyebrow {
          margin: 0;
          color: #1d4ed8;
          font-size: 11px;
          font-weight: 950;
          letter-spacing: .08em;
          text-transform: uppercase;
        }
        .status-pill {
          flex-shrink: 0;
          border-radius: 999px;
          padding: 7px 10px;
          background: #f1f5f9;
          color: #475569;
          font-size: 12px;
          font-weight: 900;
        }
        .status-pill.active {
          background: #dcfce7;
          color: #166534;
        }
        .billing-details {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 10px;
          margin-bottom: 12px;
        }
        .billing-details div {
          padding: 12px;
          border-radius: 14px;
          background: #fff;
          border: 1px solid #e2e8f0;
        }
        .billing-details span {
          display: block;
          margin-bottom: 4px;
          color: #64748b;
          font-size: 11px;
          font-weight: 800;
          text-transform: uppercase;
          letter-spacing: .05em;
        }
        .billing-details strong {
          font-size: 13px;
        }
        .billing-actions {
          grid-template-columns: 1fr 1fr;
          margin-bottom: 0;
        }
        .billing-note {
          margin: 10px 0 0;
          color: #64748b;
          font-size: 12px;
          line-height: 1.5;
        }
        .pills {
          display: flex;
          gap: 10px;
          flex-wrap: wrap;
          margin-bottom: 22px;
        }
        .pill {
          border: 1px solid #e2e8f0;
          background: #fff;
          padding: 10px 16px;
          border-radius: 999px;
          font-weight: 900;
          cursor: pointer;
        }
        .pill.active {
          background: #1d4ed8;
          color: #fff;
          border-color: #1d4ed8;
        }
        .btn {
          border: 0;
          border-radius: 14px;
          padding: 12px 14px;
          font-weight: 900;
          cursor: pointer;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          text-decoration: none;
        }
        .btn:disabled {
          opacity: .65;
          cursor: not-allowed;
        }
        .btn.secondary {
          background: rgba(248,250,252,.95);
          border: 1px solid rgba(226,232,240,.95);
          color: #0f172a;
        }
        .btn.primary {
          background: linear-gradient(135deg, #1d4ed8, #3b82f6);
          color: #fff;
        }
        .btn.ghost {
          background: transparent;
          border: 1px solid #e2e8f0;
          color: #0f172a;
        }
        .btn.danger {
          width: 100%;
          background: #dc2626;
          color: #fff;
        }
        .modal-backdrop {
          position: fixed;
          inset: 0;
          background: rgba(15,23,42,.45);
          display: grid;
          place-items: center;
          padding: 18px;
          z-index: 50;
        }
        .modal {
          width: min(440px, 100%);
          background: #fff;
          border-radius: 18px;
          padding: 18px;
          border: 1px solid #e2e8f0;
          box-shadow: 0 24px 70px rgba(15,23,42,.18);
        }
        .modal h3 {
          margin: 0 0 6px;
        }
        .muted {
          margin: 0 0 14px;
          color: #64748b;
          font-size: 13px;
          line-height: 1.5;
        }
        .field {
          display: grid;
          gap: 8px;
          margin-bottom: 12px;
        }
        .field span {
          font-size: 11px;
          font-weight: 900;
          letter-spacing: .08em;
          text-transform: uppercase;
          color: #475569;
        }
        .field input {
          height: 44px;
          border-radius: 12px;
          border: 1px solid #e2e8f0;
          padding: 0 12px;
          font: inherit;
        }
        .modal-actions {
          display: flex;
          justify-content: flex-end;
          gap: 10px;
          margin-top: 8px;
        }
      `}</style>
    </main>
  );
}

function formatPlanLabel(plan: BillingStatus["plan"]) {
  switch (plan) {
    case "pro":
      return "Pro";
    case "ultra":
      return "Ultra";
    default:
      return "Free";
  }
}

function formatStatusLabel(
  status: BillingStatus["status"],
  plan: BillingStatus["plan"],
) {
  if (!status) return plan === "free" ? "Free plan" : "Unknown";
  switch (status) {
    case "active":
      return "Active";
    case "pending":
      return "Pending";
    case "on_hold":
      return "On hold";
    case "cancelled":
      return "Cancelled";
    case "expired":
      return "Expired";
    case "failed":
      return "Payment failed";
    default:
      return capitalize(status.replaceAll("_", " "));
  }
}

function formatDate(value: string | null) {
  if (!value) return "Not scheduled";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleDateString("en-LK", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
