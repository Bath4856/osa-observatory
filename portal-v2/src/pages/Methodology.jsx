import { Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Methodology.css'

const PILLARS = [
  { code:'PECO', name:{en:'Economic Sovereignty',fr:'Souveraineté économique'}, icon:'📊', desc:{en:'GDP, trade, investment, public finance, economic diversification.',fr:'PIB, commerce, investissement, finances publiques, diversification économique.'} },
  { code:'PGEO', name:{en:'Geopolitical Sovereignty',fr:'Souveraineté géopolitique'}, icon:'🌍', desc:{en:'Diplomatic relations, alliances, geopolitical influence, territorial integrity.',fr:'Relations diplomatiques, alliances, influence géopolitique, intégrité territoriale.'} },
  { code:'PMIL', name:{en:'Military Sovereignty',fr:'Souveraineté militaire'}, icon:'🛡', desc:{en:'Defence expenditure, military capacity, security autonomy.',fr:'Dépenses de défense, capacité militaire, autonomie sécuritaire.'} },
  { code:'PMIN', name:{en:'Mineral Sovereignty',fr:'Souveraineté minière'}, icon:'⛏', desc:{en:'Extractive governance, resource value capture, mineral traceability.',fr:'Gouvernance extractive, captation de valeur des ressources, traçabilité minérale.'} },
  { code:'PMON', name:{en:'Monetary Sovereignty',fr:'Souveraineté monétaire'}, icon:'💱', desc:{en:'Currency autonomy, reserve management, monetary policy independence.',fr:'Autonomie monétaire, gestion des réserves, indépendance de la politique monétaire.'} },
  { code:'PHUM', name:{en:'Human Sovereignty',fr:'Souveraineté humaine'}, icon:'🤝', desc:{en:'Health, education, food security, human development.',fr:'Santé, éducation, sécurité alimentaire, développement humain.'} },
  { code:'PENV', name:{en:'Environmental Sovereignty',fr:'Souveraineté environnementale'}, icon:'🌿', desc:{en:'Forest cover, biodiversity, environmental governance.',fr:'Couverture forestière, biodiversité, gouvernance environnementale.'} },
  { code:'PNUM', name:{en:'Digital Sovereignty',fr:'Souveraineté numérique'}, icon:'💻', desc:{en:'Internet penetration, digital infrastructure, data governance.',fr:'Pénétration internet, infrastructure numérique, gouvernance des données.'} },
  { code:'PRES', name:{en:'Energy Sovereignty',fr:'Souveraineté énergétique'}, icon:'⚡', desc:{en:'Energy production, access, diversification, renewable capacity.',fr:'Production énergétique, accès, diversification, capacité renouvelable.'} },
  { code:'PTRA', name:{en:'Transport Sovereignty',fr:'Souveraineté des transports'}, icon:'🚢', desc:{en:'Infrastructure network, logistics capacity, connectivity.',fr:'Réseau d\'infrastructures, capacité logistique, connectivité.'} },
]

const PIPELINE = [
  { layer:'L1', label:{en:'Collect',fr:'Collecter'}, color:'#1F4E5F', desc:{en:'Primary data collection from audited international sources (World Bank WDI, FAO, SIPRI, IMF, USGS, EITI, Comtrade, ITU, WHO, UNDP). Only observed, verifiable data. Never surveys, never expert estimates.',fr:'Collecte de données primaires depuis des sources internationales auditées (Banque mondiale WDI, FAO, SIPRI, FMI, USGS, EITI, Comtrade, UIT, OMS, PNUD). Uniquement des données observées et vérifiables. Jamais des sondages, jamais des estimations d\'experts.'} },
  { layer:'L2', label:{en:'Impute',fr:'Imputer'}, color:'#2E7D6E', desc:{en:'MICE imputation applied only to homogeneous time series with less than 50% missing values. Trajectoire indicators are never imputed. Imputed values are flagged FLAG_INTERPOLATED.',fr:'Imputation MICE appliquée uniquement aux séries temporelles homogènes avec moins de 50% de valeurs manquantes. Les indicateurs TRAJECTOIRE ne sont jamais imputés. Les valeurs imputées sont marquées FLAG_INTERPOLATED.'} },
  { layer:'L3', label:{en:'Normalise',fr:'Normaliser'}, color:'#7D4800', desc:{en:'Min-max normalisation using frozen bounds v1_2026, calibrated on 2010-2020 reference data. Scores range from 0 (low sovereignty) to 1 (high sovereignty). Bounds are frozen to ensure temporal comparability.',fr:'Normalisation min-max avec bornes figées v1_2026, calibrées sur les données de référence 2010-2020. Les scores vont de 0 (souveraineté faible) à 1 (souveraineté forte). Les bornes sont figées pour garantir la comparabilité temporelle.'} },
]

const STATUS_CARDS = [
  { key:'official', label:'OFFICIAL', color:'official', desc:{en:'2020–2024 — Validated by Scientific Committee. Reference data.',fr:'2020-2024 — Validé par le Comité Scientifique. Données de référence.'} },
  { key:'preliminary', label:'PRELIMINARY', color:'preliminary', desc:{en:'2025 — Data collected, pending Scientific Committee PV validation (August 2026).',fr:'2025 — Données collectées, en attente de validation PV du Comité Scientifique (août 2026).'} },
  { key:'collecting', label:'COLLECTING', color:'collecting', desc:{en:'2026+ — Data collection in progress. Not yet available.',fr:'2026+ — Collecte de données en cours. Pas encore disponible.'} },
]

const SOURCES = ['World Bank WDI','IMF WEO','FAO FRA','SIPRI Milex','ACLED','ITU','WHO','UNDP HDR','USGS Mineral Yearbook','EITI','Comtrade HS 25-28']

export default function Methodology() {
  const { t, lang } = useLang()

  return (
    <div className="methodology-page">
      <h1 className="methodology-title">{t('methodology.title')}</h1>
      <p className="methodology-intro">{t('methodology.intro')}</p>

      <section className="method-section">
        <h2>{t('methodology.doctrine_title')}</h2>
        <div className="doctrine-block">
          <p>{t('methodology.doctrine_text')}</p>
          <ul className="doctrine-rules">
            {t('methodology.rules').map((rule, i) => (
              <li key={i}>{rule}</li>
            ))}
          </ul>
        </div>
      </section>

      <section className="method-section">
        <h2>{t('methodology.pipeline_title')}</h2>
        <div className="pipeline">
          {PIPELINE.map((step, i) => (
            <div key={step.layer} className="pipeline-step">
              <div className="step-header" style={{ background: step.color }}>
                <span className="step-layer">{step.layer}</span>
                <span className="step-label">{step.label[lang]}</span>
              </div>
              <p className="step-desc">{step.desc[lang]}</p>
              {i < PIPELINE.length - 1 && <div className="step-arrow">↓</div>}
            </div>
          ))}
        </div>
      </section>

      <section className="method-section">
        <h2>{t('methodology.normalisation_title')}</h2>
        <p>{t('methodology.normalisation_text')}</p>
      </section>

      <section className="method-section">
        <h2>{t('methodology.weighting_title')}</h2>
        <p>{t('methodology.weighting_text')}</p>
      </section>

      <section className="method-section">
        <h2>{t('methodology.status_title')}</h2>
        <div className="status-grid">
          {STATUS_CARDS.map(s => (
            <div key={s.key} className={`status-card ${s.color}`}>
              <span className="status-dot"></span>
              <div><strong>{s.label}</strong><p>{s.desc[lang]}</p></div>
            </div>
          ))}
        </div>
      </section>

      <section className="method-section">
        <h2>{t('methodology.pillars_title')}</h2>
        <p style={{marginBottom: '16px', color: 'var(--color-muted)'}}>
          {lang === 'fr'
            ? 'Chaque pilier dispose d’une fiche scientifique detaillee avec ses indicateurs, ses sources et sa doctrine.'
            : 'Each pillar has a detailed scientific page with its indicators, sources and doctrine.'}
        </p>
        <Link to="/pillars" style={{
          display: 'inline-flex', alignItems: 'center', gap: '8px',
          padding: '10px 20px', background: 'var(--color-primary)',
          color: 'white', borderRadius: '5px', fontWeight: '600',
          textDecoration: 'none', fontSize: '0.9rem'
        }}>
          {lang === 'fr' ? 'Explorer les 10 piliers souverains →' : 'Explore the 10 sovereignty pillars →'}
        </Link>
      </section>

      <section className="method-section">
        <h2>{t('methodology.sources_title')}</h2>
        <div className="sources-grid">
          {SOURCES.map(src => (
            <span key={src} className="source-tag">{src}</span>
          ))}
        </div>
      </section>
    </div>
  )
}