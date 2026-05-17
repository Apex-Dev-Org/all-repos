"use client";
import { FileCheck2, Send, ShieldCheck } from "lucide-react";

const steps = [
  {
    num: "1",
    icon: Send,
    title: "Tell us what happened",
    desc: "Share the details of your situation in your own words. It's completely private.",
  },
  {
    num: "2",
    icon: ShieldCheck,
    title: "We identify possible rights",
    desc: "Our AI analyzes Sri Lankan laws and identifies rights that may apply to you.",
  },
  {
    num: "3",
    icon: FileCheck2,
    title: "Get your action plan",
    desc: "Receive clear next steps and options you can take with confidence.",
  },
];

export default function HowItWorks() {
  return (
    <section
      id="how-it-works"
      className="bg-slow-pan"
      style={{
        position: "relative",
        overflow: "hidden",
        minHeight: 800,
        padding: "100px 0 105px",
        backgroundImage: "url('/how_aythiya_works_bg.png')",
        backgroundSize: "auto 100%",
        backgroundPosition: "center center",
        backgroundRepeat: "no-repeat",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "linear-gradient(180deg, rgba(255,255,255,0.86) 0%, rgba(255,255,255,0.38) 48%, rgba(255,255,255,0.9) 100%)",
          pointerEvents: "none",
        }}
      />

      <div className="container" style={{ position: "relative", zIndex: 1 }}>
        <div className="reveal-up" style={{ textAlign: "center", marginBottom: 54 }}>
          <h2
            style={{
              fontFamily: "Georgia, 'Times New Roman', serif",
              fontSize: "clamp(32px, 3.7vw, 48px)",
              fontWeight: 800,
              lineHeight: 1.08,
              color: "#111827",
            }}
          >
            How <span style={{ color: "#1d4ed8" }}>Aythiya AI</span> works
          </h2>
        </div>

        <div
          className="how-grid reveal-stagger"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
            gap: 34,
            maxWidth: 1180,
            margin: "0 auto",
          }}
        >
          {steps.map((s) => (
            <StepCard key={s.num} {...s} />
          ))}
        </div>
      </div>

      <style>{`
        @media(max-width:900px){
          .how-grid{ grid-template-columns:1fr !important; gap:20px !important; }
        }
      `}</style>
    </section>
  );
}

function StepCard({
  num,
  icon: Icon,
  title,
  desc,
}: {
  num: string;
  icon: React.ComponentType<{ size?: number; strokeWidth?: number }>;
  title: string;
  desc: string;
}) {
  return (
    <div
      className="premium-card"
      style={{
        minHeight: 178,
        borderRadius: 18,
        padding: "26px 28px",
        background: "rgba(255,255,255,0.72)",
        border: "1px solid rgba(255,255,255,0.84)",
        boxShadow: "0 18px 42px rgba(15,23,42,0.08)",
        backdropFilter: "blur(12px)",
        WebkitBackdropFilter: "blur(12px)",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 18,
          marginBottom: 28,
        }}
      >
        <span
          style={{
            width: 40,
            height: 40,
            borderRadius: "50%",
            background: "#1d4ed8",
            color: "#fff",
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            fontWeight: 800,
            fontSize: 16,
            boxShadow: "0 8px 18px rgba(29,78,216,0.22)",
          }}
        >
          {num}
        </span>
        <span
          style={{
            width: 42,
            height: 42,
            borderRadius: 10,
            background: "rgba(255,255,255,0.75)",
            border: "1px solid rgba(191,219,254,0.72)",
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#1d4ed8",
          }}
        >
          <Icon size={20} strokeWidth={2.2} />
        </span>
      </div>

      <h3
        style={{
          fontSize: 19,
          fontWeight: 800,
          color: "#111827",
          marginBottom: 14,
        }}
      >
        {title}
      </h3>
      <p style={{ color: "#475569", fontSize: 14, lineHeight: 1.65 }}>{desc}</p>
    </div>
  );
}
