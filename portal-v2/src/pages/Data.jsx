import { useLang } from '../i18n/useLang'
import './Data.css'

const ENDPOINTS = [
  { method:'GET', path:'/opendata/countries/latest',   desc:'Latest sovereign status for all 54 African states — ISA trajectory, AMAR risk band, pillar coverage.' },
  { method:'GET', path:'/opendata/countries/history',  desc:'Full historical ISA scores per country from 2010 to present — sovereign trajectory over time.' },
  { method:'GET', path:'/opendata/trajectories',       desc:'Sovereign trajectory signals per country and pillar — acceleration, progression, stability, decline.' },
  { method:'GET', path:'/opendata/alerts/amar',        desc:'Atrocity precursor early warning alerts (P7I-AMAR engine) — civilian protection risk bands.' },
  { method:'GET', path:'/opendata/opportunities',      desc:'Sovereign opportunity catalogue — structural projects per country and pillar.' },
  { method:'GET', path:'/api/v2/scores/{iso3}',        desc:'Full ISA score history for a single country — authenticated access.' },
  { method:'GET', path:'/api/v2/sovereignty/swot',     desc:'SWOT sovereign signals — strength, weakness, opportunity, threat per pillar per country.' },
  { method:'GET', path:'/api/v2/early-warning/conflict-economy', desc:'Conflict-economy exposure signals — resource capture, logistics, institutional risk.' },
]

export default function Data() {
  const { t } = useLang()
  const currentYear = new Date().getFullYear()

  return (
    <div className="data-page">
      <h1 className="data-title">Open Data & API</h1>

      <section className="data-section">
        <h2>Open Data — CC-BY-NC-4.0</h2>
        <p>ISA sovereign trajectories for 54 African states (2010–{currentYear}) are freely available under the Creative Commons CC-BY-NC-4.0 licence. Attribution to the OSA Observatory is required. Commercial exploitation is prohibited without a written institutional agreement.</p>
        <a href="https://api.osa-observatory.africa/opendata/countries/history" download="osa_sovereign_history.json"
          target="_blank" rel="noreferrer" className="btn-download">
          Access sovereign history data (JSON) →
        </a>
      </section>

      <section className="data-section">
        <h2>API Explorer</h2>
        <p>Interactive documentation for all OSA Observatory API endpoints. Researchers and affiliated institutions may test queries, explore data structures, and integrate sovereign indicators into their own analytical frameworks.</p>
        <a href="https://api.osa-observatory.africa/docs"
          target="_blank" rel="noreferrer" className="btn-api">
          Open API Explorer (Swagger) →
        </a>
      </section>

      <section className="data-section">
        <h2>Available Datasets</h2>
        <div className="endpoints-list">
          {ENDPOINTS.map((ep, i) => (
            <div key={i} className="endpoint-row">
              <span className="ep-method">{ep.method}</span>
              <code className="ep-path">{ep.path}</code>
              <span className="ep-desc">{ep.desc}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="data-section">
        <h2>Institutional Access</h2>
        <p>SUBSCRIBER and ADVANCED affiliates access feasibility studies, proof-of-concept documents, and sovereign intelligence reports. Six affiliation categories are available: State, Regional Organisation, International Organisation, Academic Institution, Private Sector, Development Bank.</p>
        <a href="/register" className="btn-affiliate">Request institutional affiliation →</a>
      </section>
    </div>
  )
}
