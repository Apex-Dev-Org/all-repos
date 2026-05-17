"use client";
import { useState } from "react";

type ChatMessage = {
  role: "user" | "ai";
  text: string | null;
  time: string;
  structured?: {
    intro: string;
    sections: { heading: string; points: string[] }[];
  } | null;
};

const initialMessages: ChatMessage[] = [
  {
    role: "user",
    text: "I haven't received my salary for 2 months. What can I do?",
    time: "10:34 AM",
  },
  {
    role: "ai",
    text: null,
    structured: {
      intro: "This may involve your right to receive wages under Sri Lankan law.",
      sections: [
        {
          heading: "You may have the right to:",
          points: ["Receive all unpaid salary", "Interest for delay", "Make a complaint to the Labour Department"],
        },
        {
          heading: "Next steps you can take:",
          points: ["Send a written request to your employer", "Keep records of payment due", "File a complaint if not resolved"],
        },
      ],
    },
    time: "10:34 AM",
  },
];

export default function Hero() {
  const [input, setInput] = useState("");
  const [chat, setChat] = useState<ChatMessage[]>(initialMessages);

  const send = () => {
    if (!input.trim()) return;
    const now = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    setChat(prev => [
      ...prev,
      { role: "user", text: input, time: now, structured: null },
      {
        role: "ai", text: "I'm reviewing the relevant Sri Lankan laws for your situation. Please consult a qualified lawyer for advice specific to your case.",
        time: now, structured: null
      },
    ]);
    setInput("");
  };

  return (
    <section id="home" className="premium-section" style={{ minHeight: "100vh", position: "relative", display: "flex", alignItems: "center", overflow: "hidden", paddingTop: 70 }}>
      {/* BG Image */}
      <div className="bg-kenburns" style={{
        position: "absolute", inset: 0, zIndex: 0,
        backgroundImage: "url('/hero_bg.png')", backgroundSize: "cover", backgroundPosition: "center",
      }} />

      <div className="container" style={{ position: "relative", zIndex: 2, width: "100%", paddingBottom: "60px", paddingTop: "60px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 100, alignItems: "center" }} className="hero-grid">

          {/* ── Left ── */}
          <div className="reveal-left">
            {/* Sinhala headline */}
            <h1 style={{ marginBottom: 4 }}>
              <span style={{
                fontFamily: "'Noto Sans Sinhala', sans-serif",
                fontSize: "clamp(22px, 3vw, 34px)", fontWeight: 700,
                color: "#1a1a2e", display: "block", lineHeight: 1.4,
              }}>
                දන්නවාද<br />ඔබේ අයිතිවාසිකම
              </span>
              <span style={{
                fontSize: "clamp(36px, 5vw, 58px)", fontWeight: 900,
                color: "#1a5caa", display: "block", lineHeight: 1.1, marginTop: 8,
              }}>
                Know Your Rights.
              </span>
            </h1>

            <p style={{ color: "#334155", fontSize: 16, lineHeight: 1.7, marginBottom: 32, maxWidth: 440 }}>
              Describe what happened. We&apos;ll help you understand what the law may say — and what to do next.
            </p>

            {/* Buttons */}
            <div style={{ display: "flex", gap: 14, alignItems: "center", flexWrap: "wrap", marginBottom: 36 }}>
              <a href="/chat" className="hover-lift shine-on-hover pulse-glow" style={{
                background: "#1a5caa", color: "#fff",
                padding: "13px 30px", borderRadius: 50, fontWeight: 700, fontSize: 15,
                textDecoration: "none", boxShadow: "0 6px 20px rgba(26,92,170,0.35)",
                transition: "transform 0.2s, box-shadow 0.2s",
              }}
                onMouseEnter={e => { e.currentTarget.style.transform = "translateY(-2px)"; e.currentTarget.style.boxShadow = "0 10px 28px rgba(26,92,170,0.45)"; }}
                onMouseLeave={e => { e.currentTarget.style.transform = "translateY(0)"; e.currentTarget.style.boxShadow = "0 6px 20px rgba(26,92,170,0.35)"; }}
              >Try now</a>

              <a href="#features" className="hover-lift" style={{
                display: "flex", alignItems: "center", gap: 8,
                color: "#1a5caa", fontWeight: 600, fontSize: 15, textDecoration: "none",
                transition: "opacity 0.2s",
              }}
                onMouseEnter={e => e.currentTarget.style.opacity = "0.75"}
                onMouseLeave={e => e.currentTarget.style.opacity = "1"}
              >
                <span style={{
                  width: 32, height: 32, borderRadius: "50%", border: "2px solid #1a5caa",
                  display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12,
                }}>▶</span>
                Learn how it works
              </a>
            </div>

            {/* Feature pills */}
            <div className="reveal-up" style={{
              display: "flex", gap: 10, flexWrap: "wrap",
              background: "rgba(255,255,255,0.65)", backdropFilter: "blur(10px)",
              borderRadius: 14, padding: "12px 16px", border: "1px solid rgba(255,255,255,0.8)",
              width: "fit-content",
            }}>
              {[
                { icon: "✦", label: "Powered by AI" },
                { icon: "🔒", label: "Confidential" },
                { icon: "🎁", label: "Free to use" },
                { icon: "🌐", label: "Sinhala + English" },
              ].map(p => (
                <span key={p.label} style={{
                  display: "flex", alignItems: "center", gap: 5,
                  fontSize: 12, color: "#334155", fontWeight: 500,
                  paddingRight: 12, borderRight: "1px solid #e2e8f0",
                }}
                  className="pill-item"
                >
                  <span style={{ fontSize: 13 }}>{p.icon}</span>{p.label}
                </span>
              ))}
            </div>
          </div>

          {/* ── Right — Chat Widget ── */}
          <div className="reveal-right float-soft" style={{ display: "flex", justifyContent: "flex-end", flex: "0 0 45%", marginLeft: "auto", alignSelf: "flex-start", marginTop: 20 }}>
            <div className="premium-card" style={{
              background: "rgba(255, 255, 255, 0.4)", backdropFilter: "blur(24px)", WebkitBackdropFilter: "blur(24px)",
              borderRadius: 24,
              boxShadow: "0 24px 64px rgba(0,0,0,0.12), 0 0 0 1px rgba(255,255,255,0.5) inset", overflow: "hidden",
              width: "100%", maxWidth: 440,
              border: "1px solid rgba(255, 255, 255, 0.6)",
              
            }}>
              {/* Chat Header */}
              <div style={{
                padding: "16px 20px", background: "transparent",
                borderBottom: "1px solid rgba(255, 255, 255, 0.5)",
                display: "flex", alignItems: "center", gap: 12,
              }}>
                <div style={{
                  width: 44, height: 44, borderRadius: 12,
                  background: "#2e78d4",
                  display: "flex", alignItems: "center", justifyContent: "center", fontSize: 22,
                }}>🏛️</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, fontSize: 15, color: "#0f172a" }}>LAW AI</div>
                  <div style={{ fontSize: 12, color: "#94a3b8" }}>AI Legal Assistant</div>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
                  <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#22c55e", display: "block" }} />
                  <span style={{ fontSize: 12, color: "#22c55e", fontWeight: 600 }}>Online</span>
                </div>
              </div>

              {/* Messages */}
              <div style={{
                padding: "20px", height: 340, overflowY: "auto",
                display: "flex", flexDirection: "column", gap: 16,
                background: "transparent",
              }}>
                {chat.map((m, i) => (
                  <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: m.role === "user" ? "flex-end" : "flex-start" }}>
                    {m.role === "user" ? (
                      <div>
                        <div style={{
                          background: "#dbeafe", color: "#1e3a5f",
                          padding: "14px 18px", borderRadius: "18px 18px 4px 18px",
                          fontSize: 14, lineHeight: 1.6, maxWidth: 320,
                        }}>{m.text}</div>
                        <div style={{ fontSize: 11, color: "#94a3b8", marginTop: 6, textAlign: "right", display: "flex", alignItems: "center", justifyContent: "flex-end", gap: 4 }}>
                          {m.time} <span style={{ color: "#cbd5e1" }}>✓✓</span>
                        </div>
                      </div>
                    ) : m.structured ? (
                      <div style={{
                        background: "#fff", borderRadius: "4px 18px 18px 18px",
                        padding: "18px 20px", fontSize: 14, lineHeight: 1.7,
                        boxShadow: "0 4px 12px rgba(0,0,0,0.03)", maxWidth: 360, color: "#1e293b",
                      }}>
                        <p style={{ marginBottom: 16, color: "#475569" }}>{m.structured.intro}</p>
                        {m.structured.sections.map((s, j) => (
                          <div key={j} style={{ marginBottom: j < m.structured!.sections.length - 1 ? 16 : 0 }}>
                            <p style={{ fontWeight: 700, marginBottom: 8, color: "#0f172a" }}>{s.heading}</p>
                            {s.points.map((pt, k) => (
                              <div key={k} style={{ display: "flex", gap: 8, paddingLeft: 4, color: "#475569", marginBottom: 6 }}>
                                <span style={{ color: "#94a3b8" }}>·</span><span>{pt}</span>
                              </div>
                            ))}
                          </div>
                        ))}
                        <div style={{ fontSize: 11, color: "#94a3b8", marginTop: 12, textAlign: "right" }}>{m.time}</div>
                      </div>
                    ) : (
                      <div style={{
                        background: "#fff", borderRadius: "4px 16px 16px 16px",
                        padding: "10px 14px", fontSize: 13, lineHeight: 1.6,
                        boxShadow: "0 2px 8px rgba(0,0,0,0.06)", maxWidth: 300, color: "#334155",
                      }}>
                        {m.text}
                        <div style={{ fontSize: 10, color: "#94a3b8", marginTop: 4 }}>{m.time}</div>
                      </div>
                    )}
                  </div>
                ))}
              </div>

              {/* Input */}
              <div style={{
                padding: "16px 20px 20px", background: "transparent",
                display: "flex", gap: 12, alignItems: "center",
                borderRadius: "0 0 24px 24px"
              }}>
                <div style={{
                  flex: 1,
                  display: "flex",
                  alignItems: "center",
                  border: "1px solid #e2e8f0",
                  borderRadius: 50,
                  padding: "6px 6px 6px 16px",
                  background: "#fff",
                  boxShadow: "0 2px 12px rgba(0,0,0,0.04)"
                }}>
                  <input
                    value={input} onChange={e => setInput(e.target.value)}
                    onKeyDown={e => e.key === "Enter" && send()}
                    placeholder="Ask anything about your situation..."
                    style={{
                      flex: 1, border: "none",
                      fontSize: 14, outline: "none",
                      background: "transparent", color: "#0f172a",
                    }}
                  />
                  <button onClick={send} style={{
                    background: "#1a5caa", color: "#fff",
                    border: "none", borderRadius: "50%", width: 40, height: 40,
                    cursor: "pointer", fontSize: 16,
                    display: "flex", alignItems: "center", justifyContent: "center",
                    flexShrink: 0, transition: "background 0.2s",
                    boxShadow: "0 2px 8px rgba(26,92,170,0.3)"
                  }}>➤</button>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>

      <style>{`
        @keyframes fadeInLeft { from{opacity:0;transform:translateX(-40px)} to{opacity:1;transform:translateX(0)} }
        @keyframes fadeInRight { from{opacity:0;transform:translateX(40px)} to{opacity:1;transform:translateX(0)} }
        .pill-item:last-child { border-right: none !important; padding-right: 0 !important; }
        @media(max-width:768px){
          .hero-grid { grid-template-columns:1fr !important; gap:32px !important; }
        }
      `}</style>
    </section>
  );
}
