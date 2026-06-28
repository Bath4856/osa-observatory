import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Pillar.css'

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

// Definitions doctrinales statiques (nom, definition, sources)
const PILLAR_DATA = {
  PGEO: { name:{en:'Geopolitical Sovereignty',fr:'Souveraineté géopolitique'}, definition:{en:'Measures the capacity of a state to assert its geopolitical position, maintain diplomatic relations, and exercise influence in international affairs independently of external pressure.',fr:'Mesure la capacité d\'un État à affirmer sa position géopolitique, maintenir des relations diplomatiques et exercer une influence dans les affaires internationales indépendamment de toute pression extérieure.'}, sources:['ACLED','UN Treaty Database','African Union','World Bank WDI'] },
  PECO: { name:{en:'Economic Sovereignty',fr:'Souveraineté économique'}, definition:{en:'Measures the structural capacity of a national economy to generate, retain, and redistribute value internally, independent of external economic dependencies.',fr:'Mesure la capacité structurelle d\'une économie nationale à générer, retenir et redistribuer de la valeur en interne, indépendamment des dépendances économiques extérieures.'}, sources:['World Bank WDI','IMF WEO','ILO','UNCTAD'] },
  PMIL: { name:{en:'Military Sovereignty',fr:'Souveraineté militaire'}, definition:{en:'Measures the autonomous defence capacity of a state — its ability to protect territorial integrity and maintain internal security without structural dependency on foreign military forces.',fr:'Mesure la capacité de défense autonome d\'un État — sa capacité à protéger l\'intégrité territoriale et maintenir la sécurité intérieure sans dépendance structurelle aux forces militaires étrangères.'}, sources:['SIPRI Milex','World Bank WDI'] },
  PMIN: { name:{en:'Mineral Sovereignty',fr:'Souveraineté minière'}, definition:{en:'Measures the degree to which a state captures the economic value of its mineral resources, controls extraction governance, and resists illicit financial flows from the mining sector.',fr:'Mesure le degré auquel un État capte la valeur économique de ses ressources minières, contrôle la gouvernance extractive et résiste aux flux financiers illicites du secteur minier.'}, sources:['USGS Mineral Yearbook','EITI','Comtrade HS 25-28','World Bank Pink Sheet'] },
  PMON: { name:{en:'Monetary Sovereignty',fr:'Souveraineté monétaire'}, definition:{en:'Measures the degree of control a state exercises over its monetary system — currency issuance, exchange rate management, and resistance to dollarisation or monetary subordination.',fr:'Mesure le degré de contrôle qu\'un État exerce sur son système monétaire — émission de monnaie, gestion du taux de change, et résistance à la dollarisation ou à la subordination monétaire.'}, sources:['IMF IFS','World Bank WDI','BIS'] },
  PHUM: { name:{en:'Human Sovereignty',fr:'Souveraineté humaine'}, definition:{en:'Measures the capacity of a state to ensure the fundamental conditions of human development — health, education, nutrition — for its population, independently of foreign aid dependency.',fr:'Mesure la capacité d\'un État à assurer les conditions fondamentales du développement humain — santé, éducation, nutrition — pour sa population, indépendamment de la dépendance à l\'aide étrangère.'}, sources:['UNDP HDR','WHO','World Bank WDI'] },
  PENV: { name:{en:'Environmental Sovereignty',fr:'Souveraineté environnementale'}, definition:{en:'Measures the capacity of a state to govern its natural environment, preserve biodiversity, and maintain territorial ecological integrity against external exploitation.',fr:'Mesure la capacité d\'un État à gouverner son environnement naturel, préserver la biodiversité et maintenir l\'intégrité écologique territoriale contre l\'exploitation extérieure.'}, sources:['FAO FRA','World Bank WDI','UNEP'] },
  PNUM: { name:{en:'Digital Sovereignty',fr:'Souveraineté numérique'}, definition:{en:'Measures the capacity of a state to develop, govern, and protect its digital infrastructure and data assets independently of foreign technology dependency.',fr:'Mesure la capacité d\'un État à développer, gouverner et protéger son infrastructure numérique et ses actifs de données indépendamment de la dépendance technologique étrangère.'}, sources:['ITU','World Bank WDI'] },
  PRES: { name:{en:'Energy Sovereignty',fr:'Souveraineté énergétique'}, definition:{en:'Measures the capacity of a state to produce, distribute, and govern its energy resources autonomously, reducing dependency on imported fossil fuels.',fr:'Mesure la capacité d\'un État à produire, distribuer et gouverner ses ressources énergétiques de manière autonome, en réduisant la dépendance aux combustibles fossiles importés.'}, sources:['IEA','World Bank WDI','IRENA'] },
  PTRA: { name:{en:'Transport Sovereignty',fr:'Souveraineté des transports'}, definition:{en:'Measures the density, quality, and autonomy of a state transport infrastructure — roads, railways, ports, and aviation — as a vector of economic and territorial integration.',fr:'Mesure la densité, la qualité et l\'autonomie de l\'infrastructure de transport d\'un État — routes, voies ferrées, ports et aviation — en tant que vecteur d\'intégration économique et territoriale.'}, sources:['World Bank WDI','ITF','ICAO'] },
}

export default function Pillar() {
  const { code } = useParams()
  const { t, lang } = useLang()
  const [indicators, setIndicators] = useState([])
  const [loadingInd, setLoadingInd] = useState(true)

  const pillar = PILLAR_DATA[code]

  useEffect(() => {
    if (!code) return
    setLoadingInd(true)
    fetch(`${API}/opendata/indicators/${code}`)
      .then(r => r.ok ? r.json() : null)
      .then(data => setIndicators(data?.indicators || []))
      .catch(() => setIndicators([]))
      .finally(() => setLoadingInd(false))
  }, [code])

  if (!pillar) return (
    <div className="pillar-page">
      <p>Pillar not found: {code}</p>
      <Link to="/pillars">{t('pillar.back')}</Link>
    </div>
  )

  const withData    = indicators.filter(i => i.has_data)
  const withoutData = indicators.filter(i => !i.has_data)

  return (
    <div className="pillar-page">
      <div className="pillar-header">
        <span className="pillar-code-badge">{code}</span>
        <h1 className="pillar-title">{pillar.name[lang]}</h1>
        <Link to="/pillars" className="back-link">{t('pillar.back')}</Link>
      </div>

      <section className="pillar-section">
        <h2>{t('pillar.definition')}</h2>
        <p>{pillar.definition[lang]}</p>
      </section>

      <section className="pillar-section">
        <h2>{t('pillar.indicators')}</h2>
        {loadingInd ? (
          <p style={{color:'var(--color-muted)', fontSize:'.9rem'}}>
            {lang === 'fr' ? 'Chargement...' : 'Loading...'}
          </p>
        ) : (
          <>
            {withData.length > 0 && (
              <>
                <p className="ind-section-label">
                  {lang === 'fr'
                    ? `${withData.length} indicateur${withData.length > 1 ? 's' : ''} avec données observées`
                    : `${withData.length} indicator${withData.length > 1 ? 's' : ''} with observed data`}
                </p>
                <div className="indicators-list">
                  {withData.map(ind => (
                    <span key={ind.code} className="indicator-tag indicator-tag--active" title={lang === 'fr' ? ind.name_fr : ind.name_en}>
                      {ind.code}
                    </span>
                  ))}
                </div>
              </>
            )}
            {withoutData.length > 0 && (
              <>
                <p className="ind-section-label ind-section-label--muted" style={{marginTop:'12px'}}>
                  {lang === 'fr'
                    ? `${withoutData.length} indicateur${withoutData.length > 1 ? 's' : ''} définis — collecte en cours`
                    : `${withoutData.length} indicator${withoutData.length > 1 ? 's' : ''} defined — collection in progress`}
                </p>
                <div className="indicators-list">
                  {withoutData.map(ind => (
                    <span key={ind.code} className="indicator-tag indicator-tag--pending" title={lang === 'fr' ? ind.name_fr : ind.name_en}>
                      {ind.code}
                    </span>
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </section>

      <section className="pillar-section">
        <h2>{t('pillar.sources')}</h2>
        <ul className="sources-list">
          {pillar.sources.map(src => <li key={src}>{src}</li>)}
        </ul>
      </section>

      <section className="pillar-section">
        <h2>{t('pillar.doctrine')}</h2>
        <p>{t('pillar.doctrine_text')}</p>
      </section>
    </div>
  )
}
