"use client";
export default function CTA() {
  return (
    <section
      id="contact"
      className="premium-section"
      style={{
        padding: "86px 0 98px",
        background: "#fff",
        textAlign: "center",
      }}
    >
      <div className="container">
        <img
          className="float-soft reveal-up"
          src="/aythiya_logo.png"
          alt="Aythiya"
          style={{
            width: 230,
            maxWidth: "70%",
            height: "auto",
            objectFit: "contain",
            margin: "0 auto 28px",
            display: "block",
          }}
        />

        <h2
          className="reveal-up"
          style={{
            color: "#1f2937",
            fontSize: "clamp(30px, 4vw, 44px)",
            fontWeight: 900,
            lineHeight: 1.15,
            marginBottom: 18,
          }}
        >
          Have a Legal Query? Ask for Free.
        </h2>

        <p
          className="reveal-up"
          style={{
            color: "#0f172a",
            fontSize: "clamp(16px, 2vw, 20px)",
            fontWeight: 600,
            lineHeight: 1.55,
            margin: "0 auto 28px",
            maxWidth: 760,
          }}
        >
          Sri Lanka&apos;s first law AI chatbot. Understand the law without
          paying for a lawyer.
        </p>

        <a
          href="#how-it-works"
          className="hover-lift shine-on-hover pulse-glow"
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 10,
            background: "#2563eb",
            color: "#fff",
            padding: "13px 23px",
            borderRadius: 10,
            fontWeight: 800,
            fontSize: 15,
            textDecoration: "none",
            boxShadow: "0 8px 20px rgba(37,99,235,0.22)",
            transition: "transform 0.2s, box-shadow 0.2s, background 0.2s",
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.transform = "translateY(-2px)";
            e.currentTarget.style.background = "#1d4ed8";
            e.currentTarget.style.boxShadow = "0 12px 28px rgba(37,99,235,0.3)";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = "translateY(0)";
            e.currentTarget.style.background = "#2563eb";
            e.currentTarget.style.boxShadow = "0 8px 20px rgba(37,99,235,0.22)";
          }}
        >
          <span style={{ fontSize: 15, lineHeight: 1 }}>▷</span>
          Learn how it works
        </a>
      </div>
    </section>
  );
}
