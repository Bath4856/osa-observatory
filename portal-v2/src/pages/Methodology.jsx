import { Link } from 'react-router-dom'
import './Methodology.css'

const PILLARS = [
  { code:'PECO', name:'Economic Sovereignty', icon:'📊', desc:'GDP, trade, investment, public finance, economic diversification.' },
  { code:'PGEO', name:'Geopolitical Sovereignty', icon:'🌍', desc:'Diplomatic relations, alliances, geopolitical influence, territorial integrity.' },
  { code:'PMIL', name:'Military Sovereignty', icon:'🛡', desc:'Defence expenditure, military capacity, security autonomy.' },
  { code:'PMIN', name:'Mineral Sovereignty', icon:'⛏', desc:'Extractive governance, resource value capture, mineral traceability.' },
  { code:'PMON', name:'Monetary Sovereignty', icon:'💱', desc:'Currency autonomy, reserve management, monetary policy independence.' },
  { code:'PHUM', name:'Human Sovereignty', icon:'🤝', desc:'Health, education, food security, human development.' },
  { code:'PENV', name:'Environmental Sovereignty', icon:'🌿', desc:'Forest cover, biodiversity, environmental governance.' },
  { code:'PNUM', name:'Digital Sovereignty', icon:'💻', desc:'Internet penetration, digital infrastructure, data governance.' },
  { code:'PRES', name:'Energy Sovereignty', icon:'⚡', desc:'Energy production, access, diversification, renewable capacity.' },
  { code:'PTRA', name:'Transport Sovereignty', icon:'🚢', desc:'Infrastructure network, logistics capacity, connectivity.' },
]

const PIPELINE = [
  { layer:'L1', label:'Collect', color:'#1F4E5F', desc:'Primary data collection from audited international sources (World Bank WDI, FAO, SIPRI, IMF, USGS, EITI, Comtrade, ITU, WHO, UNDP). Only observed, verifiable data. Never surveys, never expert estimates.' },
  { layer:'L2', label:'Impute', color:'#2E7D6E', desc:'MICE imputation applied only to homogeneous time series with less than 50% missing values. Trajectoire indicators are never imputed. Imputed values are flagged FLAG_INTERPOLATED.' },
  { layer:'L3', label:'Normalise', color:'#7D4800', desc:'Min-max normalisation using frozen bounds v1_2026, calibrated on 2010-2020 reference data. Scores range from 0 (low sovereignty) to 1 (high sovereignty). Bounds are frozen to ensure temporal comparability.' },
]

export default function Methodology() {
  return (
    <div className="methodology-page">
      <h1 className="methodology-title">ISA Methodology</h1>
      <p className="methodology-intro">
        The Index of African Sovereignty (ISA) is computed from observed, primary,
        auditable data — never surveys, never expert estimates. The methodology
        follows the OSA P7E consequentialist doctrine.
      </p>

      <section className="method-section">
        <h2>Doctrine P7E — Consequentialist</h2>
        <div className="doctrine-block">
          <p>For decades, Africa has been evaluated through indices built on <strong>perceptions</strong>. OSA proposes a different approach: observing the <strong>real capabilities</strong> of African states from verifiable behavioural data, tracking their <strong>trajectories over time</strong> and informing public decisions with facts rather than perceptions.</p>
          <ul className="doctrine-rules">
            <li>Every indicator is a <strong>primary observable datum</strong> — collected from an audited, geolocated, dated source</li>
            <li>Perception-based indicators (WGI, CPI) are <strong>permanently excluded</strong> — demonstrated OECD evaluator bias</li>
            <li>No country is compared to another — each is observed against its <strong>own sovereign trajectory</strong></li>
            <li>Indicators without observed data <strong>do not participate</strong> in weighting</li>
            <li>Imputation rate above 50% → indicator <strong>inactive</strong></li>
          </ul>
        </div>
      </section>

      <section className="method-section">
        <h2>3-Layer Pipeline</h2>
        <div className="pipeline">
          {PIPELINE.map((step, i) => (
            <div key={step.layer} className="pipeline-step">
              <div className="step-header" style={{ background: step.color }}>
                <span className="step-layer">{step.layer}</span>
                <span className="step-label">{step.label}</span>
              </div>
              <p className="step-desc">{step.desc}</p>
              {i < PIPELINE.length - 1 && <div className="step-arrow">↓</div>}
            </div>
          ))}
        </div>
      </section>

      <section className="method-section">
        <h2>Normalisation — Frozen Bounds v1_2026</h2>
        <p>Min-max normalisation : <code>score = (value - min) / (max - min)</code> for positive indicators, inverted for negative ones. Bounds are frozen on the 2010–2020 reference period (freeze version v1_2026) — ensuring that new data does not shift historical scores. Dynamic bounds are used as fallback only when frozen bounds are unavailable.</p>
      </section>

      <section className="method-section">
        <h2>Weighting</h2>
        <p>Equal weighting within each pillar — each active indicator receives <code>1/n</code> weight where n is the number of indicators with observed data. The 10 pillars are equally weighted in the ISA composite. Weights are automatically renormalized when indicators are activated or deactivated.</p>
      </section>

      <section className="method-section">
        <h2>Publication Status</h2>
        <div className="status-grid">
          <div className="status-card official">
            <span className="status-dot"></span>
            <div>
              <strong>OFFICIAL</strong>
              <p>2020–2024 — Validated by Scientific Committee. Reference data.</p>
            </div>
          </div>
          <div className="status-card preliminary">
            <span className="status-dot"></span>
            <div>
              <strong>PRELIMINARY</strong>
              <p>2025 — Data collected, pending Scientific Committee PV validation (August 2026).</p>
            </div>
          </div>
          <div className="status-card collecting">
            <span className="status-dot"></span>
            <div>
              <strong>COLLECTING</strong>
              <p>2026+ — Data collection in progress. Not yet available.</p>
            </div>
          </div>
        </div>
      </section>

      <section className="method-section">
        <h2>The 10 Pillars</h2>
        <div className="pillars-grid">
          {PILLARS.map(p => (
            <Link key={p.code} to={`/pillar/${p.code}`} className="pillar-card">
              <span className="pillar-icon">{p.icon}</span>
              <span className="pillar-code">{p.code}</span>
              <span className="pillar-name">{p.name}</span>
              <span className="pillar-desc">{p.desc}</span>
            </Link>
          ))}
        </div>
      </section>

      <section className="method-section">
        <h2>Data Sources</h2>
        <div className="sources-grid">
          {['World Bank WDI','IMF WEO','FAO FRA','SIPRI Milex','ACLED','ITU','WHO','UNDP HDR',
            'USGS Mineral Yearbook','EITI','Comtrade HS 25-28'].map(src => (
            <span key={src} className="source-tag">{src}</span>
          ))}
        </div>
      </section>
    </div>
  )
}
