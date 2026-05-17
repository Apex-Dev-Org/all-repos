"use client";
export default function About() {
  return (
    <section id="about" className="premium-section" style={{ padding: "90px 0", background: "#fff" }}>
      <div className="container">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 64, alignItems: "center" }} className="about-grid">

          {/* Image */}
          <div className="reveal-left" style={{ position: "relative", display: "flex", justifyContent: "center" }}>
            <img src="/lady_justice.png" alt="Lady Justice" style={{
              width: "min(1560px, 100%)", objectFit: "contain", position: "relative", zIndex: 1,
              animation: "floatBob 4s ease-in-out infinite"
            }} />
            <style>{`@keyframes floatBob{0%,100%{transform:translateY(0)}50%{transform:translateY(-14px)}}`}</style>
          </div>

          {/* Text */}
          <div className="reveal-right">
            <span style={{
              background: "linear-gradient(135deg,#e8f0fe,#dbeafe)", color: "#2b7cdfff",
              padding: "6px 18px", borderRadius: 50, fontSize: 13, fontWeight: 600
            }}>About Aythiya</span>

            <h2 style={{ fontSize: "clamp(28px,4vw,42px)", fontWeight: 800, lineHeight: 1.2, margin: "16px 0" }}>
              Your Trusted <span style={{ color: "#1a5caa" }}>AI Legal</span> Companion
            </h2>

            <p style={{ color: "#64748b", lineHeight: 1.8, marginBottom: 20, fontSize: 16 }}>
              Aythiya (ආතිය) is Sri Lanka&apos;s pioneering AI-powered legal assistant, built to bridge the gap between citizens and the justice system. We believe every Sri Lankan deserves access to quality legal guidance — regardless of income or location.
            </p>
            <p style={{ color: "#64748b", lineHeight: 1.8, marginBottom: 32, fontSize: 16 }}>
              Our AI is trained on Sri Lankan statutes, court precedents, and legal codes to provide accurate, context-aware answers in Sinhala, Tamil, and English.
            </p>

            <div className="reveal-stagger" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 32 }}>
              {[
                { icon: "🤖", t: "AI-Powered Answers" },
                { icon: "🌐", t: "3 Language Support" },
                { icon: "🔒", t: "100% Confidential" },
                { icon: "⚡", t: "Instant Responses" },
              ].map(f => (
                <div key={f.t} className="hover-lift" style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <span style={{
                    width: 36, height: 36, borderRadius: 10, background: "#e8f0fe",
                    display: "flex", alignItems: "center", justifyContent: "center", fontSize: 17, flexShrink: 0
                  }}>{f.icon}</span>
                  <span style={{ fontWeight: 600, fontSize: 14 }}>{f.t}</span>
                </div>
              ))}
            </div>

            <a href="#contact" className="hover-lift shine-on-hover" style={{
              display: "inline-block", background: "linear-gradient(135deg,#1a5caa,#2e78d4)",
              color: "#fff", padding: "14px 32px", borderRadius: 50, fontWeight: 700, fontSize: 15,
              textDecoration: "none", boxShadow: "0 8px 24px rgba(26,92,170,0.3)",
              transition: "transform 0.2s"
            }}
              onMouseEnter={e => e.currentTarget.style.transform = "translateY(-2px)"}
              onMouseLeave={e => e.currentTarget.style.transform = "translateY(0)"}
            >Learn More →</a>
          </div>
        </div>
      </div>
      <style>{`
        @media(max-width:768px){ .about-grid{ grid-template-columns:1fr !important; gap:32px !important; } }
      `}</style>
    </section>
  );
}
