"use client";
const areas = [
  { icon:"⚖️", title:"Civil Law", desc:"Property disputes, contracts, torts" },
  { icon:"👨‍👩‍👧", title:"Family Law", desc:"Divorce, custody, inheritance" },
  { icon:"🏢", title:"Labour Law", desc:"Employee rights, EPF, ETF" },
  { icon:"🏠", title:"Property Law", desc:"Land deeds, rent disputes" },
  { icon:"🚔", title:"Criminal Law", desc:"Rights, bail, court procedure" },
  { icon:"💼", title:"Business Law", desc:"Companies, contracts, IP" },
];

export default function LawAreas() {
  return (
    <section className="premium-section" style={{ padding:"16px  0 80px 0", background:"#fff" }}>
      <div className="container">
        <div className="reveal-up" style={{ textAlign:"center", marginBottom:16 }}>
          <span style={{
            background:"linear-gradient(135deg,#e8f0fe,#dbeafe)", color:"#1a5caa",
            padding:"6px 18px", borderRadius:50, fontSize:13, fontWeight:600
          }}>Comprehensive Coverage</span>
        </div>
        <h2 className="reveal-up" style={{ textAlign:"center", fontSize:"clamp(26px,4vw,38px)", fontWeight:800, marginBottom:12 }}>
          Covers Every Area of <span style={{ color:"#1a5caa" }}>Sri Lankan Law</span>
        </h2>
        <p className="reveal-up" style={{ textAlign:"center", color:"#64748b", fontSize:16, maxWidth:560, margin:"0 auto 48px" }}>
          From family matters to corporate disputes — Aythiya has you covered with accurate, up-to-date legal knowledge.
        </p>

        {/* Award badges */}
        <div className="reveal-stagger" style={{ display:"flex", justifyContent:"center", gap:24, flexWrap:"wrap", marginBottom:56 }}>
          {[
            { label:"Most Trusted Legal AI", sub:"Sri Lanka 2025" },
            { label:"Best Legal Innovation Award", sub:"Ministry of Justice" },
            { label:"Top Rated Legal App", sub:"10,000+ Reviews" },
          ].map(b => (
            <div key={b.label} className="hover-lift float-soft" style={{
              display:"flex", flexDirection:"column", alignItems:"center", gap:8,
              backgroundImage:"url('/gold_border.png')", backgroundSize:"100% 100%", backgroundRepeat:"no-repeat", backgroundPosition:"center",
              padding:"50px 100px", minWidth:280
            }}>
              <span style={{ fontSize:28 }}>🏆</span>
              <span style={{ fontWeight:700, fontSize:13, textAlign:"center", color:"#0f172a" }}>{b.label}</span>
              <span style={{ fontSize:11, color:"#64748b" }}>{b.sub}</span>
            </div>
          ))}
        </div>

        {/* Area Cards */}
        <div className="reveal-stagger" style={{ display:"grid", gridTemplateColumns:"repeat(auto-fit,minmax(180px,1fr))", gap:20 }}>
          {areas.map((a,i) => (
            <div key={i} className="premium-card" style={{
              background:"linear-gradient(135deg,#f8faff,#eef4ff)",
              border:"1px solid #e2ecf8", borderRadius:16, padding:"24px 20px",
              textAlign:"center", transition:"transform 0.25s, box-shadow 0.25s", cursor:"default"
            }}
            onMouseEnter={e=>{e.currentTarget.style.transform="translateY(-6px)"; e.currentTarget.style.boxShadow="0 16px 40px rgba(26,92,170,0.14)";}}
            onMouseLeave={e=>{e.currentTarget.style.transform="translateY(0)"; e.currentTarget.style.boxShadow="none";}}>
              <div style={{ fontSize:32, marginBottom:12 }}>{a.icon}</div>
              <div style={{ fontWeight:700, fontSize:15, marginBottom:6 }}>{a.title}</div>
              <div style={{ fontSize:12, color:"#64748b" }}>{a.desc}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
