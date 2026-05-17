"use client";

import { useTranslation } from "../../i18n/useTranslation";

export default function Footer() {
  const { t } = useTranslation();

  const columns = [
    { titleKey: "footerProduct" as const, links: ["Features", "How it Works", "Pricing", "FAQ", "Blog"] },
    { titleKey: "footerLegal" as const, links: ["Privacy Policy", "Terms of Use", "Cookie Policy", "Disclaimer"] },
    { titleKey: "footerCompany" as const, links: ["About Us", "Contact", "Careers", "Press Kit"] },
  ];

  return (
    <footer className="premium-section" style={{ background: "#0a1628", color: "rgba(255,255,255,0.75)", paddingTop: 60 }}>
      <div className="container">
        <div
          style={{ display: "grid", gridTemplateColumns: "2fr 1fr 1fr 1fr", gap: 40, paddingBottom: 48 }}
          className="footer-grid reveal-stagger"
        >
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16 }}>
              <img src="/aythiya_logo.png" alt={t("loginBrandTitle")} style={{ width: 36, height: 36 }} />
              <span style={{ fontFamily: "'Noto Sans Sinhala',sans-serif", fontSize: 20, fontWeight: 700, color: "#fff" }}>
                {t("loginBrandTitle")}
              </span>
            </div>
            <p style={{ fontSize: 14, lineHeight: 1.8, maxWidth: 260 }}>{t("loginSubtitle")}</p>
            <div style={{ display: "flex", gap: 12, marginTop: 20 }}>
              {["𝕏", "in", "📘", "📸"].map((icon, i) => (
                <a
                  key={i}
                  href="#"
                  className="hover-lift"
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: "50%",
                    background: "rgba(255,255,255,0.08)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: 15,
                    color: "#fff",
                    textDecoration: "none",
                    transition: "background 0.2s",
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = "rgba(26,92,170,0.5)")}
                  onMouseLeave={(e) => (e.currentTarget.style.background = "rgba(255,255,255,0.08)")}
                >
                  {icon}
                </a>
              ))}
            </div>
          </div>

          {columns.map((col) => (
            <div key={col.titleKey}>
              <h4 style={{ color: "#fff", fontWeight: 700, marginBottom: 16, fontSize: 15 }}>{t(col.titleKey)}</h4>
              {col.links.map((link) => (
                <a
                  key={link}
                  href="#"
                  style={{
                    display: "block",
                    color: "rgba(255,255,255,0.6)",
                    textDecoration: "none",
                    fontSize: 14,
                    marginBottom: 10,
                    transition: "color 0.2s",
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.color = "#f5c842")}
                  onMouseLeave={(e) => (e.currentTarget.style.color = "rgba(255,255,255,0.6)")}
                >
                  {link}
                </a>
              ))}
            </div>
          ))}
        </div>

        <div
          style={{
            borderTop: "1px solid rgba(255,255,255,0.08)",
            padding: "24px 0",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            flexWrap: "wrap",
            gap: 12,
          }}
        >
          <span style={{ fontSize: 13 }}>{t("footerCopyright")}</span>
          <span style={{ fontSize: 13 }}>{t("footerLocaleLine")}</span>
        </div>
      </div>

      <style>{`
        @media(max-width:768px){ .footer-grid{ grid-template-columns:1fr 1fr !important; gap:24px !important; } }
        @media(max-width:480px){ .footer-grid{ grid-template-columns:1fr !important; } }
      `}</style>
    </footer>
  );
}
