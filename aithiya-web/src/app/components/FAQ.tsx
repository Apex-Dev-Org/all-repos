"use client";
import { useState } from "react";

const faqs = [
  { q:"Is Aythiya free to use?", a:"Yes! Aythiya is completely free for all Sri Lankan citizens. We believe access to legal knowledge is a fundamental right." },
  { q:"What languages does Aythiya support?", a:"Aythiya supports Sinhala (සිංහල), Tamil (தமிழ்), and English. You can ask your question in any of these languages." },
  { q:"Is my conversation confidential?", a:"Absolutely. All conversations are encrypted and fully confidential. We never share your personal information or legal queries with third parties." },
  { q:"Can Aythiya replace a real lawyer?", a:"Aythiya provides legal information and guidance, but for complex cases requiring representation in court, we always recommend consulting a qualified lawyer. We can help you find one!" },
  { q:"What types of legal questions can I ask?", a:"You can ask about civil law, family law, property, employment, criminal procedure, business, and more — covering most areas of Sri Lankan law." },
  { q:"How accurate is the information provided?", a:"Aythiya is trained on official Sri Lankan statutes and updated court decisions. However, laws can change — always verify critical decisions with a licensed attorney." },
];

export default function FAQ() {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <section id="faq" className="premium-section" style={{ padding:"90px 0", background:"#fff" }}>
      <div className="container">
        <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:60, alignItems:"start" }} className="faq-grid">

          {/* Left */}
          <div className="reveal-left">
            <span style={{
              background:"linear-gradient(135deg,#e8f0fe,#dbeafe)", color:"#1a5caa",
              padding:"6px 18px", borderRadius:50, fontSize:13, fontWeight:600
            }}>FAQ</span>
            <h2 style={{ fontSize:"clamp(26px,4vw,38px)", fontWeight:800, margin:"16px 0 16px" }}>
              Frequently Asked <span style={{ color:"#1a5caa" }}>Questions</span>
            </h2>
            <p style={{ color:"#64748b", lineHeight:1.7, marginBottom:32 }}>
              Got questions about Aythiya? We&apos;ve answered the most common ones below.
            </p>

            <img className="float-slow" src="/faq_justice.png" alt="Sri Lanka Legal" style={{
              width:"100%", height:"auto", objectFit:"contain", display:"block"
            }}/>
          </div>

          {/* Right — Accordion */}
          <div className="reveal-stagger" style={{ display:"flex", flexDirection:"column", gap:12 }}>
            {faqs.map((f,i) => (
              <div key={i} className="premium-card" style={{
                border:`1px solid ${open===i?"#1a5caa":"#e2ecf8"}`,
                borderRadius:16, overflow:"hidden",
                transition:"border-color 0.25s",
                boxShadow: open===i?"0 4px 20px rgba(26,92,170,0.1)":"none"
              }}>
                <button onClick={() => setOpen(open===i ? null : i)} style={{
                  width:"100%", padding:"18px 20px", background: open===i?"linear-gradient(135deg,#e8f0fe,#dbeafe)":"#f8faff",
                  border:"none", cursor:"pointer", textAlign:"left",
                  display:"flex", justifyContent:"space-between", alignItems:"center", gap:12
                }}>
                  <span style={{ fontWeight:600, fontSize:15, color: open===i?"#1a5caa":"#0f172a" }}>{f.q}</span>
                  <span style={{
                    width:28, height:28, borderRadius:"50%",
                    background: open===i?"#1a5caa":"#e2ecf8",
                    color: open===i?"#fff":"#64748b",
                    display:"flex", alignItems:"center", justifyContent:"center", fontSize:16, flexShrink:0,
                    transition:"all 0.25s", transform: open===i?"rotate(45deg)":"rotate(0)"
                  }}>+</span>
                </button>
                {open===i && (
                  <div style={{ padding:"16px 20px", background:"#fff", color:"#64748b", fontSize:14, lineHeight:1.7 }}>
                    {f.a}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
      <style>{`
        @media(max-width:768px){ .faq-grid{ grid-template-columns:1fr !important; gap:32px !important; } }
      `}</style>
    </section>
  );
}
