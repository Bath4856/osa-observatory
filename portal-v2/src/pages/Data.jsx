import './Data.css'

const ENDPOINTS = [
  { method:'GET', path:'/opendata/scores',          desc:'ISA scores — all countries, all years' },
  { method:'GET', path:'/opendata/scores/{iso3}',   desc:'ISA scores — single country' },
  { method:'GET', path:'/opendata/governance',      desc:'Observatory KPIs and governance metrics' },
  { method:'GET', path:'/opendata/predictive-status', desc:'P7Z predictive layer readiness status' },
  { method:'GET', path:'/api/v2/scores',            desc:'ISA scores with pillar detail (authenticated)' },
  { method:'GET', path:'/api/v2/sovereignty/swot',  desc:'SWOT signals and sovereign trajectories' },
  { method:'GET', path:'/api/v2/sovereign-projects',desc:'Sovereign project catalogue' },
  { method:'GET', path:'/api/v2/early-warning/conflict-economy', desc:'Early warnings — conflict economy' },
]

export default function Data() {
  return (
    <div className="data-page">
      <h1 className="data-title">Open Data & API</h1>

      <section className="data-section">
        <h2>Open Data — CC-BY-NC-4.0</h2>
        <p>ISA scores and sovereign trajectories for 54 African countries (2010–2024) are freely available under the Creative Commons CC-BY-NC-4.0 licence. Attribution required. Commercial use prohibited without written agreement.</p>
        <a href="https://api.osa-observatory.africa/opendata/scores"
          target="_blank" rel="noreferrer" className="btn-download">
          Download scores (JSON) →
        </a>
      </section>

      <section className="data-section">
        <h2>API Explorer</h2>
        <p>Interactive documentation for all OSA Observatory API endpoints. Test queries directly from your browser.</p>
        <a href="https://api.osa-observatory.africa/docs"
          target="_blank" rel="noreferrer" className="btn-api">
          Open API Explorer (Swagger) →
        </a>
      </section>

      <section className="data-section">
        <h2>Available Endpoints</h2>
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
        <h2>Affiliation & Advanced Access</h2>
        <p>SUBSCRIBER and ADVANCED affiliates gain access to feasibility studies, POC documents, and advanced analytical reports. Five affiliation types are available : State, Regional Organisation, Academic, Private Sector, Development Bank.</p>
        <a href="/register" className="btn-affiliate">Request affiliation →</a>
      </section>
    </div>
  )
}
