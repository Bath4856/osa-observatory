import { useParams, Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Pillar.css'

const PILLAR_DATA = {
  PGEO: { name:{en:'Geopolitical Sovereignty',fr:'Souverainete geopolitique'}, definition:{en:'Measures the capacity of a state to assert its geopolitical position, maintain diplomatic relations, and exercise influence in international affairs independently of external pressure.',fr:'Mesure la capacite d un Etat a affirmer sa position geopolitique, maintenir des relations diplomatiques et exercer une influence dans les affaires internationales independamment de toute pression exterieure.'}, indicators:['GEO_SOVEREIGN_MARGIN','GEO_DIP_NETWORK','GEO_ORG_MEMBERSHIP','GEO_CONFLICT_EXPOSURE'], sources:['ACLED','UN Treaty Database','African Union','World Bank WDI'] },
  PECO: { name:{en:'Economic Sovereignty',fr:'Souverainete economique'}, definition:{en:'Measures the structural capacity of a national economy to generate, retain, and redistribute value internally, independent of external economic dependencies.',fr:'Mesure la capacite structurelle d une economie nationale a generer, retenir et redistribuer de la valeur en interne, independamment des dependances economiques exterieures.'}, indicators:['ECO_GDP','ECO_GRW','ECO_TAX','ECO_FDI','ECO_UNE','ECO_AGR','ECO_EMP','ECO_INV','ECO_PUBLIC_LEAKAGE','ECO_TAX_EFFICIENCY'], sources:['World Bank WDI','IMF WEO','ILO','UNCTAD'] },
  PMIL: { name:{en:'Military Sovereignty',fr:'Souverainete militaire'}, definition:{en:'Measures the autonomous defence capacity of a state — its ability to protect territorial integrity and maintain internal security without structural dependency on foreign military forces.',fr:'Mesure la capacite de defense autonome d un Etat — sa capacite a proteger l integrite territoriale et maintenir la securite interieure sans dependance structurelle aux forces militaires etrangeres.'}, indicators:['MIL_EXPENDITURE','MIL_PERSONNEL','MIL_EQUIPMENT'], sources:['SIPRI Milex','World Bank WDI'] },
  PMIN: { name:{en:'Mineral Sovereignty',fr:'Souverainete miniere'}, definition:{en:'Measures the degree to which a state captures the economic value of its mineral resources, controls extraction governance, and resists illicit financial flows from the mining sector.',fr:'Mesure le degre auquel un Etat capte la valeur economique de ses ressources minieres, controle la gouvernance extractive et resiste aux flux financiers illicites du secteur minier.'}, indicators:['MIN_RES','PMIN_VALUE_CAPTURE','PMIN_VALUE_LEAKAGE','MIN_LEAKAGE_RISK'], sources:['USGS Mineral Yearbook','EITI','Comtrade HS 25-28','World Bank Pink Sheet'] },
  PMON: { name:{en:'Monetary Sovereignty',fr:'Souverainete monetaire'}, definition:{en:'Measures the degree of control a state exercises over its monetary system — currency issuance, exchange rate management, and resistance to dollarisation or monetary subordination.',fr:'Mesure le degre de controle qu un Etat exerce sur son systeme monetaire — emission de monnaie, gestion du taux de change, et resistance a la dollarisation ou a la subordination monetaire.'}, indicators:['MON_RES','MON_IFF_PRESSURE','PMON_RESERVE_CAPTURE'], sources:['IMF IFS','World Bank WDI','BIS'] },
  PHUM: { name:{en:'Human Sovereignty',fr:'Souverainete humaine'}, definition:{en:'Measures the capacity of a state to ensure the fundamental conditions of human development — health, education, nutrition — for its population, independently of foreign aid dependency.',fr:'Mesure la capacite d un Etat a assurer les conditions fondamentales du developpement humain — sante, education, nutrition — pour sa population, independamment de la dependance a l aide etrangere.'}, indicators:['HUM_HDI','HUM_HEA_EXPENDITURE','HUM_EDU','PHUM_VALUE_CAPTURE'], sources:['UNDP HDR','WHO','World Bank WDI'] },
  PENV: { name:{en:'Environmental Sovereignty',fr:'Souverainete environnementale'}, definition:{en:'Measures the capacity of a state to govern its natural environment, preserve biodiversity, and maintain territorial ecological integrity against external exploitation.',fr:'Mesure la capacite d un Etat a gouverner son environnement naturel, preserver la biodiversite et maintenir l integrite ecologique territoriale contre l exploitation exterieure.'}, indicators:['ENV_FOR','ENV_CO2','ENV_PROTECTED'], sources:['FAO FRA','World Bank WDI','UNEP'] },
  PNUM: { name:{en:'Digital Sovereignty',fr:'Souverainete numerique'}, definition:{en:'Measures the capacity of a state to develop, govern, and protect its digital infrastructure and data assets independently of foreign technology dependency.',fr:'Mesure la capacite d un Etat a developper, gouverner et proteger son infrastructure numerique et ses actifs de donnees independamment de la dependance technologique etrangere.'}, indicators:['NUM_INTERNET','NUM_MOBILE','PNUM_DIGITAL_CAPTURE'], sources:['ITU','World Bank WDI'] },
  PRES: { name:{en:'Energy Sovereignty',fr:'Souverainete energetique'}, definition:{en:'Measures the capacity of a state to produce, distribute, and govern its energy resources autonomously, reducing dependency on imported fossil fuels.',fr:'Mesure la capacite d un Etat a produire, distribuer et gouverner ses ressources energetiques de maniere autonome, en reduisant la dependance aux combustibles fossiles importes.'}, indicators:['RES_PRODUCTION','RES_ACCESS','RES_RENEWABLE'], sources:['IEA','World Bank WDI','IRENA'] },
  PTRA: { name:{en:'Transport Sovereignty',fr:'Souverainete des transports'}, definition:{en:'Measures the density, quality, and autonomy of a state transport infrastructure — roads, railways, ports, and aviation — as a vector of economic and territorial integration.',fr:'Mesure la densite, la qualite et l autonomie de l infrastructure de transport d un Etat — routes, voies ferrees, ports et aviation — en tant que vecteur d integration economique et territoriale.'}, indicators:['TRA_ROAD','TRA_RAIL','TRA_PORT','TRA_AIR'], sources:['World Bank WDI','ITF','ICAO'] },
}

export default function Pillar() {
  const { code } = useParams()
  const { t, lang } = useLang()
  const pillar = PILLAR_DATA[code]

  if (!pillar) return (
    <div className="pillar-page">
      <p>Pillar not found : {code}</p>
      <Link to="/methodology">{t('pillar.back')}</Link>
    </div>
  )

  return (
    <div className="pillar-page">
      <div className="pillar-header">
        <span className="pillar-code-badge">{code}</span>
        <h1 className="pillar-title">{pillar.name[lang]}</h1>
        <Link to="/methodology" className="back-link">{t('pillar.back')}</Link>
      </div>
      <section className="pillar-section">
        <h2>{t('pillar.definition')}</h2>
        <p>{pillar.definition[lang]}</p>
      </section>
      <section className="pillar-section">
        <h2>{t('pillar.indicators')}</h2>
        <div className="indicators-list">
          {pillar.indicators.map(ind => (
            <span key={ind} className="indicator-tag">{ind}</span>
          ))}
        </div>
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
