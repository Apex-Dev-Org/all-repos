"use client";

import { useState } from "react";
import {
  Check,
  Crown,
  Lock,
  ShieldCheck,
  Sparkles,
  X,
  Zap,
} from "lucide-react";
import { authService } from "../../services/authService";
import { getValidAccessToken } from "../../services/authSession";

const PRODUCT_IDS = {
  Pro: {
    monthly: process.env.NEXT_PUBLIC_DODO_PRO_MONTH_ID ?? "",
    yearly: process.env.NEXT_PUBLIC_DODO_PRO_YEAR_ID ?? "",
  },
  Ultra: {
    monthly: process.env.NEXT_PUBLIC_DODO_ULTRA_MONTH_ID ?? "",
    yearly: process.env.NEXT_PUBLIC_DODO_ULTRA_YEAR_ID ?? "",
  },
} as const;

function formatLkr(amount: number) {
  return `Rs. ${amount.toLocaleString("en-LK")}`;
}

const plans = [
  {
    name: "Free",
    price: "Rs. 0",
    period: "forever",
    description: "For citizens who need quick legal clarity.",
    icon: ShieldCheck,
    popular: false,
    cta: "Start Free",
    amount: 0,
    features: [
      "25 AI legal questions per month",
      "Sinhala, Tamil, and English support",
      "Basic rights and next-step guidance",
      "Save up to 3 chat threads",
      "Community legal resources",
    ],
  },
  {
    name: "Pro",
    price: "Rs. 1,490",
    period: "per month",
    description: "For students, workers, freelancers, and families.",
    icon: Zap,
    popular: true,
    cta: "Upgrade to Pro",
    amount: 1490,
    features: [
      "500 AI legal questions per month",
      "Document OCR and explanation",
      "File uploads up to 25MB",
      "Unlimited saved chat threads",
      "Smart notes and case organization",
      "Priority response speed",
    ],
  },
  {
    name: "Ultra",
    price: "Rs. 4,990",
    period: "per month",
    description: "For small businesses, teams, and frequent users.",
    icon: Crown,
    popular: false,
    cta: "Go Ultra",
    amount: 4990,
    features: [
      "Unlimited AI legal questions",
      "Advanced document review",
      "Team workspace for 5 users",
      "Case-law powered research mode",
      "Large file uploads up to 50MB",
      "Early access to premium features",
    ],
  },
];

type PaidPlan = Extract<(typeof plans)[number], { amount: number }> & {
  amount: number;
};

export default function Pricing() {
  const [checkoutPlan, setCheckoutPlan] = useState<PaidPlan | null>(null);

  return (
    <section
      id="pricing"
      className="premium-section"
      style={{
        padding: "100px 0",
        background:
          "linear-gradient(180deg, #ffffff 0%, #f8fbff 52%, #ffffff 100%)",
        position: "relative",
        overflow: "hidden",
      }}
    >
      <div
        aria-hidden
        style={{
          position: "absolute",
          width: 460,
          height: 460,
          borderRadius: "50%",
          background: "rgba(191,219,254,0.38)",
          filter: "blur(70px)",
          top: -160,
          right: -120,
        }}
      />

      <div className="container" style={{ position: "relative", zIndex: 1 }}>
        <div
          className="reveal-up"
          style={{ textAlign: "center", marginBottom: 54 }}
        >
          <span
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              padding: "7px 16px",
              borderRadius: 999,
              background: "#dbeafe",
              color: "#1d4ed8",
              fontSize: 13,
              fontWeight: 800,
            }}
          >
            <Sparkles size={15} />
            Simple Pricing
          </span>
          <h2
            style={{
              fontSize: "clamp(30px, 4vw, 46px)",
              fontWeight: 900,
              letterSpacing: "-0.03em",
              margin: "16px 0 12px",
              color: "#0f172a",
            }}
          >
            Choose the plan that fits your legal needs
          </h2>
          <p
            style={{
              color: "#64748b",
              fontSize: 16,
              lineHeight: 1.7,
              maxWidth: 680,
              margin: "0 auto",
            }}
          >
            Start free, then upgrade when you need document analysis, unlimited
            chats, team workflows, and faster legal guidance.
          </p>
        </div>

        <div
          className="pricing-grid reveal-stagger"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
            gap: 24,
            maxWidth: 1180,
            margin: "0 auto",
          }}
        >
          {plans.map((plan) => (
            <PlanCard
              key={plan.name}
              {...plan}
              onUpgrade={() => {
                if (!authService.isAuthenticated()) {
                  window.location.href = `/login?next=${encodeURIComponent("/#pricing")}`;
                  return;
                }
                setCheckoutPlan(plan);
              }}
            />
          ))}
        </div>

        <p
          className="reveal-up"
          style={{
            textAlign: "center",
            color: "#94a3b8",
            fontSize: 12,
            lineHeight: 1.7,
            maxWidth: 760,
            margin: "28px auto 0",
          }}
        >
          Prices are shown in Sri Lankan Rupees and exclude any applicable
          taxes. Aythiya provides legal information and guidance, not formal
          legal representation.
        </p>
        <p
          className="reveal-up"
          style={{
            textAlign: "center",
            color: "#64748b",
            fontSize: 13,
            lineHeight: 1.7,
            margin: "10px auto 0",
          }}
        >
          Already subscribed? Manage payment methods, invoices, and
          cancellations from{" "}
          <a href="/settings" style={{ color: "#1d4ed8", fontWeight: 900 }}>
            Settings
          </a>
          .
        </p>
      </div>

      {checkoutPlan && (
        <CheckoutModal
          plan={checkoutPlan}
          onClose={() => setCheckoutPlan(null)}
        />
      )}

      <style>{`
        @media(max-width: 980px) {
          .pricing-grid { grid-template-columns: 1fr !important; max-width: 560px !important; }
        }
      `}</style>
    </section>
  );
}

function PlanCard({
  name,
  price,
  period,
  description,
  icon: Icon,
  popular,
  cta,
  features,
  onUpgrade,
}: (typeof plans)[number] & { onUpgrade: () => void }) {
  const isFree = name === "Free";

  return (
    <article
      className="premium-card"
      style={{
        position: "relative",
        padding: 28,
        borderRadius: 26,
        background: popular
          ? "linear-gradient(180deg, rgba(255,255,255,0.95), rgba(239,246,255,0.92))"
          : "rgba(255,255,255,0.82)",
        border: popular ? "2px solid #1d4ed8" : "1px solid #dbeafe",
        boxShadow: popular
          ? "0 22px 60px rgba(29,78,216,0.18)"
          : "0 14px 38px rgba(15,23,42,0.06)",
        backdropFilter: "blur(16px)",
      }}
    >
      {popular && (
        <div
          style={{
            position: "absolute",
            top: 18,
            right: 18,
            padding: "6px 11px",
            borderRadius: 999,
            background: "#1d4ed8",
            color: "#fff",
            fontSize: 11,
            fontWeight: 900,
            letterSpacing: ".04em",
          }}
        >
          MOST POPULAR
        </div>
      )}

      <div
        style={{
          width: 48,
          height: 48,
          borderRadius: 15,
          display: "grid",
          placeItems: "center",
          background: popular ? "#1d4ed8" : "#dbeafe",
          color: popular ? "#fff" : "#1d4ed8",
          marginBottom: 18,
        }}
      >
        <Icon size={23} />
      </div>

      <h3 style={{ fontSize: 24, fontWeight: 900, marginBottom: 8 }}>{name}</h3>
      <p
        style={{
          color: "#64748b",
          fontSize: 14,
          lineHeight: 1.6,
          minHeight: 44,
        }}
      >
        {description}
      </p>

      <div style={{ margin: "22px 0 24px" }}>
        <span style={{ fontSize: 38, fontWeight: 950, color: "#0f172a" }}>
          {price}
        </span>
        <span style={{ color: "#64748b", fontWeight: 700 }}> / {period}</span>
      </div>

      <button
        type="button"
        onClick={() => {
          if (isFree) {
            window.location.href = authService.isAuthenticated()
              ? "/chat"
              : `/login?next=${encodeURIComponent("/chat")}`;
            return;
          }
          onUpgrade();
        }}
        className="hover-lift shine-on-hover"
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          width: "100%",
          minHeight: 48,
          borderRadius: 14,
          textDecoration: "none",
          fontWeight: 900,
          color: popular ? "#fff" : "#1d4ed8",
          background: popular ? "#1d4ed8" : "#eff6ff",
          border: popular ? "0" : "1px solid #bfdbfe",
          boxShadow: popular ? "0 12px 28px rgba(29,78,216,0.25)" : "none",
          cursor: "pointer",
        }}
      >
        {cta}
      </button>

      <ul
        style={{
          listStyle: "none",
          display: "grid",
          gap: 12,
          marginTop: 24,
          padding: 0,
        }}
      >
        {features.map((feature) => (
          <li
            key={feature}
            style={{
              display: "flex",
              alignItems: "flex-start",
              gap: 10,
              color: "#334155",
              fontSize: 14,
              lineHeight: 1.45,
            }}
          >
            <Check
              size={17}
              color="#1d4ed8"
              style={{ marginTop: 1, flexShrink: 0 }}
            />
            {feature}
          </li>
        ))}
      </ul>
    </article>
  );
}

function CheckoutModal({
  plan,
  onClose,
}: {
  plan: PaidPlan;
  onClose: () => void;
}) {
  const [message, setMessage] = useState("");
  const [cycle, setCycle] = useState<"monthly" | "yearly">("monthly");
  const billingPrice = formatLkr(
    cycle === "yearly" ? plan.amount * 12 : plan.amount,
  );
  const billingPeriod = cycle === "yearly" ? "per year" : plan.period;

  function resolveProductId(): string {
    switch (plan.name) {
      case "Pro":
        return PRODUCT_IDS.Pro[cycle];
      case "Ultra":
        return PRODUCT_IDS.Ultra[cycle];
      default:
        return "";
    }
  }

  const startCheckout = async () => {
    setMessage("");
    const productId = resolveProductId();
    if (!productId) {
      setMessage(
        `This ${cycle} plan is not configured. Set the matching NEXT_PUBLIC_DODO_*_${cycle === "yearly" ? "YEAR" : "MONTH"}_ID value in .env.local`,
      );
      return;
    }

    const token = await getValidAccessToken();
    if (!token) {
      setMessage("Please sign in before upgrading your plan.");
      return;
    }

    const params = new URLSearchParams();
    params.set("productId", productId);
    params.set("quantity", "1");

    const user = authService.getUser?.() as
      | { email?: string; name?: string }
      | undefined;
    if (user?.email) params.set("email", user.email);
    if (user?.name) params.set("fullName", user.name);

    try {
      const res = await fetch(`/checkout?${params.toString()}`, {
        method: "GET",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      if (!res.ok) {
        const data = (await res.json().catch(() => ({}))) as {
          error?: string;
        };
        throw new Error(data.error ?? `Checkout failed: ${res.status}`);
      }
      const data = (await res.json()) as Record<string, unknown>;
      const url = String(
        (data as Record<string, unknown>).checkout_url ??
          (data as Record<string, unknown>).url ??
          "",
      );
      if (!url) throw new Error("No checkout_url returned");
      window.location.href = url;
    } catch (err) {
      const msg =
        err instanceof Error ? err.message : "Failed to start checkout";
      setMessage(msg);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 1000,
        display: "grid",
        placeItems: "center",
        padding: 20,
        background: "rgba(15,23,42,0.48)",
        backdropFilter: "blur(10px)",
      }}
      onClick={onClose}
    >
      <div
        onClick={(event) => event.stopPropagation()}
        style={{
          width: "min(760px, 100%)",
          borderRadius: 28,
          overflow: "hidden",
          background: "#fff",
          boxShadow: "0 34px 90px rgba(15,23,42,0.28)",
          border: "1px solid rgba(219,234,254,0.9)",
        }}
      >
        <div
          style={{
            padding: 24,
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            borderBottom: "1px solid #e2e8f0",
          }}
        >
          <div>
            <p
              style={{
                color: "#1d4ed8",
                fontWeight: 900,
                fontSize: 12,
                marginBottom: 5,
              }}
            >
              SECURE CHECKOUT
            </p>
            <h3 style={{ fontSize: 26, fontWeight: 950, margin: 0 }}>
              Upgrade to {plan.name}
            </h3>
          </div>
          <button
            onClick={onClose}
            aria-label="Close checkout"
            style={{
              width: 38,
              height: 38,
              borderRadius: "50%",
              border: "1px solid #e2e8f0",
              background: "#fff",
              cursor: "pointer",
              display: "grid",
              placeItems: "center",
            }}
          >
            <X size={18} />
          </button>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "0.95fr 1.05fr",
            gap: 0,
          }}
          className="checkout-body"
        >
          <div style={{ padding: 24, background: "#f8fbff" }}>
            <div
              style={{
                padding: 20,
                borderRadius: 22,
                background: "#fff",
                border: "1px solid #dbeafe",
              }}
            >
              <p style={{ color: "#64748b", fontWeight: 800, fontSize: 13 }}>
                Plan
              </p>
              <h4 style={{ fontSize: 24, fontWeight: 950, margin: "6px 0" }}>
                {plan.name}
              </h4>
              <div style={{ margin: "14px 0" }}>
                <span style={{ fontSize: 36, fontWeight: 950 }}>
                  {billingPrice}
                </span>
                <span style={{ color: "#64748b", fontWeight: 800 }}>
                  {" "}
                  / {billingPeriod}
                </span>
              </div>
              <p style={{ color: "#64748b", lineHeight: 1.6, fontSize: 14 }}>
                Your subscription renews {cycle}. You can cancel before the
                next billing cycle.
              </p>
            </div>

            <div
              style={{
                marginTop: 14,
                display: "flex",
                alignItems: "center",
                gap: 8,
                color: "#1d4ed8",
                fontSize: 12,
                fontWeight: 900,
              }}
            >
              <Lock size={14} />
              Encrypted payment handoff
            </div>
          </div>

          <div style={{ padding: 24 }}>
            <p style={{ fontWeight: 900, marginBottom: 14 }}>
              Billing cycle
            </p>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: 10,
                marginBottom: 18,
              }}
            >
              {(["monthly", "yearly"] as const).map((item) => (
                <button
                  key={item}
                  type="button"
                  onClick={() => {
                    setCycle(item);
                    setMessage("");
                  }}
                  style={{
                    minHeight: 42,
                    borderRadius: 14,
                    border:
                      cycle === item
                        ? "2px solid #1d4ed8"
                        : "1px solid #e2e8f0",
                    background: cycle === item ? "#eff6ff" : "#fff",
                    color: cycle === item ? "#1d4ed8" : "#334155",
                    fontWeight: 900,
                    textTransform: "capitalize",
                    cursor: "pointer",
                  }}
                >
                  {item}
                </button>
              ))}
            </div>

            <div
              style={{
                display: "flex",
                gap: 12,
                alignItems: "center",
                padding: 14,
                borderRadius: 16,
                border: "1px solid #e2e8f0",
                background: "#fff",
              }}
            >
              <span
                style={{
                  width: 42,
                  height: 42,
                  borderRadius: 13,
                  display: "grid",
                  placeItems: "center",
                  color: "#1d4ed8",
                  background: "#dbeafe",
                  flexShrink: 0,
                }}
              >
                <Lock size={20} />
              </span>
              <span>
                <strong style={{ display: "block", color: "#0f172a" }}>
                  Dodo hosted checkout
                </strong>
                <small style={{ color: "#64748b", lineHeight: 1.4 }}>
                  Payment method selection happens on the secure checkout page.
                </small>
              </span>
            </div>

            {message && (
              <p
                style={{
                  marginTop: 14,
                  padding: 12,
                  borderRadius: 14,
                  background: "#fff7ed",
                  color: "#9a3412",
                  fontSize: 13,
                  lineHeight: 1.5,
                  fontWeight: 700,
                }}
              >
                {message}
              </p>
            )}

            <button
              type="button"
              onClick={startCheckout}
              className="hover-lift shine-on-hover"
              style={{
                marginTop: 18,
                width: "100%",
                minHeight: 50,
                border: 0,
                borderRadius: 15,
                background: "#1d4ed8",
                color: "#fff",
                fontWeight: 950,
                cursor: "pointer",
                boxShadow: "0 14px 30px rgba(29,78,216,0.25)",
              }}
            >
              Continue to Pay {billingPrice}
            </button>
          </div>
        </div>
      </div>

      <style>{`
        @media(max-width: 760px) {
          .checkout-body { grid-template-columns: 1fr !important; }
        }
      `}</style>
    </div>
  );
}
