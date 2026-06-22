import { useLang } from '../i18n/useLang'
import './Data.css'

const ENDPOINTS = [
  { method:'GET', path:'/opendata/countries/latest',   desc:{en:'Latest sovereign status for all 54 African states — ISA trajectory, AMAR risk band, pillar coverage.',fr:'Dernier statut souverain pour les 54 États africains — trajectoire ISA, bande de risque AMAR, couverture des piliers.'} },
  { method:'GET', path:'/opendata/countries/history',  desc:{en:'Full historical ISA scores per country from 2010 to present — sovereign trajectory over time.',fr:"Scores ISA historiques complets par pays de 2010 à aujourd'hui — trajectoire souveraine dans le temps."} },
  { method:'GET', path:'/opendata/trajectories',       desc:{en:'Sovereign trajectory signals per country and pillar — acceleration, progression, stability, decline.',fr:'Signaux de trajectoire souveraine par pays et pilier — accélération, progression, stabilité, déclin.'} },
  { method:'GET', path:'/opendata/alerts/amar',        desc:{en:'Atrocity precursor early warning alerts (P7I-AMAR engine) — civilian protection risk bands.',fr:"Alertes précoces de précurseurs d'atrocités (moteur P7I-AMAR) — bandes de risque de protection civile."} },
  { method:'GET', path:'/opendata/opportunities',      desc:{en:'Sovereign opportunity catalogue — structural projects per country and pillar.',fr:"Catalogue d'opportunités souveraines — projets structurants par pays et pilier."} },
  { method:'GET', path:'/api/v2/scores/{iso3}',        desc:{en:'Full ISA score history for a single country — authenticated access.',fr:'Historique complet des scores ISA pour un pays — accès authentifié.'} },
  { method:'GET', path:'/api/v2/sovereignty/swot',     desc:{en:'SWOT sovereign signals — strength, weakness, opportunity, threat per pillar per country.',fr:'Signaux souverains SWOT — force, faiblesse, opportunité, menace par pilier par pays.'} },
  { method:'GET', path:'/api/v2/early-warning/conflict-economy', desc:{en:'Conflict-economy exposure signals — resource capture, logistics, institutional risk.',fr:"Signaux d'exposition à l'économie de conflit — captation de ressources, logistique, risque institutionnel."} },
]

export default function Data() {
  const { t, lang } = useLang()
  const currentYear = new Date().getFullYear()

  return (
    <div className="data-page">
      <h1 className="data-title">{t('data.title')}</h1>

      <section className="data-section">
        <h2>{t('data.opendata_title')}</h2>
        <p>{t('data.opendata_text').replace('{year}', currentYear)}</p>
        <a href="https://api.osa-observatory.africa/opendata/countries/history"
          download="osa_sovereign_history.json"
          target="_blank" rel="noreferrer" className="btn-download">
          {t('data.opendata_btn')} →
        </a>
      </section>

      <section className="data-section">
        <h2>{t('data.api_title')}</h2>
        <p>{t('data.api_text')}</p>
        <a href="https://api.osa-observatory.africa/docs"
          target="_blank" rel="noreferrer" className="btn-api">
          {t('data.api_btn')} →
        </a>
      </section>

      <section className="data-section">
        <h2>{t('data.datasets_title')}</h2>
        <div className="endpoints-list">
          {ENDPOINTS.map((ep, i) => (
            <div key={i} className="endpoint-row">
              <span className="ep-method">{ep.method}</span>
              <code className="ep-path">{ep.path}</code>
              <span className="ep-desc">{ep.desc[lang]}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="data-section">
        <h2>{t('data.access_title')}</h2>
        <p>{t('data.access_text')}</p>
        <a href="/register" className="btn-affiliate">{t('data.access_btn')} →</a>
      </section>
    </div>
  )
}