"use client";

import type { ComponentType } from "react";
import {
  FileText,
  Languages,
  MessageSquareText,
  Mic,
  Scale,
  Search,
  ShieldCheck,
  StickyNote,
} from "lucide-react";

const features = [
  {
    icon: MessageSquareText,
    title: "AI Legal Chat",
    desc: "Ask about any real scenario. Get an explanation with the relevant law.",
    tone: "#1d4ed8",
  },
  {
    icon: FileText,
    title: "Document OCR",
    desc: "Upload a notice, letter or police report and get it explained clearly.",
    tone: "#0f766e",
  },
  {
    icon: StickyNote,
    title: "Smart Notes",
    desc: "Save chats, add notes, organize into collections, and track everything.",
    tone: "#ea580c",
  },
  {
    icon: Scale,
    title: "Case Laws",
    desc: "Find cases relevant to your question with short explanations.",
    tone: "#2563eb",
  },
  {
    icon: Search,
    title: "Files Storage",
    desc: "Keep your documents, PDFs, forms, images in one place.",
    tone: "#0284c7",
  },
  {
    icon: Languages,
    title: "Multi-Language",
    desc: "Works in Sinhala, Tamil, and English.",
    tone: "#f59e0b",
  },
  {
    icon: Mic,
    title: "Voice Input",
    desc: "Speak, record, upload voice notes or ask questions by audio.",
    tone: "#1d4ed8",
  },
  {
    icon: ShieldCheck,
    title: "Privacy First",
    desc: "End-to-end encryption. No data sharing. You control your conversations.",
    tone: "#dc2626",
  },
];

export default function Features() {
  return (
    <section
      id="features"
      className="bg-slow-pan"
      style={{
        position: "relative",
        overflow: "hidden",
        minHeight: 640,
        padding: "105px 0 120px",
        backgroundImage: "url('/what_we_can_do_bg.png')",
        backgroundSize: "cover",
        backgroundPosition: "center",
        backgroundRepeat: "no-repeat",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "linear-gradient(180deg, rgba(255,255,255,0.58) 0%, rgba(255,255,255,0.18) 45%, rgba(255,255,255,0.72) 100%)",
          pointerEvents: "none",
        }}
      />

      <div className="container" style={{ position: "relative", zIndex: 1 }}>
        <div className="reveal-up" style={{ textAlign: "center", marginBottom: 52 }}>
          <h2
            style={{
              fontFamily: "Georgia, 'Times New Roman', serif",
              fontSize: "clamp(30px, 3.5vw, 46px)",
              fontWeight: 800,
              lineHeight: 1.05,
              color: "#0b3f84",
              marginBottom: 14,
            }}
          >
            What You Can Do with
            <br />
            Aythiya
          </h2>
          <p
            style={{
              color: "#475569",
              fontSize: 13,
              maxWidth: 720,
              margin: "0 auto",
            }}
          >
            Eight tools, all included free. From chat to document OCR to voice
            input.
          </p>
        </div>

        <div
          className="features-grid reveal-stagger"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(4, minmax(0, 1fr))",
            gap: 18,
            maxWidth: 1060,
            margin: "0 auto",
          }}
        >
          {features.map((f) => (
            <FeatureCard key={f.title} {...f} />
          ))}
        </div>
      </div>

      <style>{`
        @media(max-width:1024px){
          .features-grid{ grid-template-columns:repeat(2,minmax(0,1fr)) !important; }
        }
        @media(max-width:640px){
          #features{ padding:80px 0 90px !important; }
          .features-grid{ grid-template-columns:1fr !important; }
        }
      `}</style>
    </section>
  );
}

function FeatureCard({
  icon: Icon,
  title,
  desc,
  tone,
}: {
  icon: ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;
  title: string;
  desc: string;
  tone: string;
}) {
  return (
    <div
      className="premium-card"
      style={{
        minHeight: 150,
        borderRadius: 16,
        padding: "24px 22px",
        background: "rgba(255,255,255,0.72)",
        border: "1px solid rgba(255,255,255,0.86)",
        boxShadow: "0 14px 42px rgba(29,78,216,0.10)",
        backdropFilter: "blur(12px)",
        WebkitBackdropFilter: "blur(12px)",
        transition: "transform 0.25s, box-shadow 0.25s",
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = "translateY(-6px)";
        e.currentTarget.style.boxShadow = "0 20px 48px rgba(29,78,216,0.18)";
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.transform = "translateY(0)";
        e.currentTarget.style.boxShadow = "0 14px 42px rgba(29,78,216,0.10)";
      }}
    >
      <div
        style={{
          width: 34,
          height: 34,
          borderRadius: 9,
          background: "rgba(219,234,254,0.8)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          marginBottom: 14,
        }}
      >
        <Icon size={17} color={tone} strokeWidth={2.4} />
      </div>

      <h3
        style={{
          color: "#0f172a",
          fontWeight: 800,
          fontSize: 15,
          marginBottom: 8,
        }}
      >
        {title}
      </h3>
      <p style={{ color: "#475569", fontSize: 12, lineHeight: 1.55 }}>{desc}</p>
    </div>
  );
}
