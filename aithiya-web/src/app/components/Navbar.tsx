"use client";

import { useState } from "react";
import type { TranslationKey } from "../../i18n/types";
import { useTranslation } from "../../i18n/useTranslation";

const NAV_ITEMS: { key: TranslationKey; hash: string }[] = [
  { key: "navHome", hash: "home" },
  { key: "navFeatures", hash: "features" },
  { key: "navAbout", hash: "about" },
  { key: "navPricing", hash: "pricing" },
  { key: "navFaq", hash: "faq" },
  { key: "navContact", hash: "contact" },
];

export default function Navbar() {
  const { t } = useTranslation();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav
      className="reveal-up"
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        right: 0,
        zIndex: 100,
        borderBottom: "1px solid rgba(26,92,170,0.1)",
        boxShadow: "0 2px 20px rgba(26,92,170,0.08)",
      }}
    >
      <div
        className="container"
        style={{ display: "flex", alignItems: "center", justifyContent: "space-between", height: 70 }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <img
            src="/aythiya_logo.png"
            alt={t("loginBrandTitle")}
            style={{ width: 38, height: 38, objectFit: "contain" }}
          />
          <span style={{ fontFamily: "'Noto Sans Sinhala', sans-serif", fontSize: 22, fontWeight: 700, color: "#1a5caa" }}>
            {t("loginBrandTitle")}
          </span>
        </div>

        <div style={{ display: "flex", gap: 32, alignItems: "center" }} className="desktop-nav">
          {NAV_ITEMS.map((item) => (
            <a
              key={item.key}
              href={`#${item.hash}`}
              style={{
                color: "#334155",
                textDecoration: "none",
                fontSize: 14,
                fontWeight: 500,
                transition: "color 0.2s",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.color = "#1a5caa")}
              onMouseLeave={(e) => (e.currentTarget.style.color = "#334155")}
            >
              {t(item.key)}
            </a>
          ))}
        </div>

        <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
          <a
            href="/login"
            className="hover-lift shine-on-hover"
            style={{
              background: "linear-gradient(135deg,#1a5caa,#2e78d4)",
              color: "#fff",
              padding: "10px 22px",
              borderRadius: 50,
              fontSize: 14,
              fontWeight: 600,
              textDecoration: "none",
              transition: "transform 0.2s, box-shadow 0.2s",
              boxShadow: "0 4px 14px rgba(26,92,170,0.3)",
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = "translateY(-2px)";
              e.currentTarget.style.boxShadow = "0 8px 24px rgba(26,92,170,0.4)";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = "translateY(0)";
              e.currentTarget.style.boxShadow = "0 4px 14px rgba(26,92,170,0.3)";
            }}
          >
            {t("navAskForFree")}
          </a>

          <button
            type="button"
            onClick={() => setMenuOpen(!menuOpen)}
            className="hamburger"
            aria-label={menuOpen ? t("chatCloseSidebar") : t("chatOpenSidebar")}
            style={{
              display: "none",
              background: "none",
              border: "none",
              cursor: "pointer",
              flexDirection: "column",
              gap: 5,
              padding: 4,
            }}
          >
            {[0, 1, 2].map((i) => (
              <span key={i} style={{ display: "block", width: 22, height: 2, background: "#1a5caa", borderRadius: 2 }} />
            ))}
          </button>
        </div>
      </div>

      {menuOpen && (
        <div style={{ background: "#fff", padding: "16px 24px", borderTop: "1px solid var(--border)" }}>
          {NAV_ITEMS.map((item) => (
            <a
              key={item.key}
              href={`#${item.hash}`}
              onClick={() => setMenuOpen(false)}
              style={{
                display: "block",
                padding: "12px 0",
                color: "#334155",
                textDecoration: "none",
                fontSize: 15,
                fontWeight: 500,
                borderBottom: "1px solid #f1f5f9",
              }}
            >
              {t(item.key)}
            </a>
          ))}
        </div>
      )}

      <style>{`
        @media(max-width:768px){
          .desktop-nav { display:none !important; }
          .hamburger { display:flex !important; }
        }
      `}</style>
    </nav>
  );
}
