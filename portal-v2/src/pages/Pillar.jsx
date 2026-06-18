import { useParams, Link } from 'react-router-dom'
import './Pillar.css'

const PILLAR_DATA = {
  PGEO: {
    name: 'Geopolitical Sovereignty',
    definition: 'Measures the capacity of a state to assert its geopolitical position, maintain diplomatic relations, and exercise influence in international affairs independently of external pressure.',
    indicators: ['GEO_SOVEREIGN_MARGIN','GEO_DIP_NETWORK','GEO_ORG_MEMBERSHIP','GEO_CONFLICT_EXPOSURE'],
    sources: ['ACLED','UN Treaty Database','African Union','World Bank WDI'],
  },
  PECO: {
    name: 'Economic Sovereignty',
    definition: 'Measures the structural capacity of a national economy to generate, retain, and redistribute value internally, independent of external economic dependencies.',
    indicators: ['ECO_GDP','ECO_GRW','ECO_TAX','ECO_FDI','ECO_UNE','ECO_AGR','ECO_EMP','ECO_INV','ECO_PUBLIC_LEAKAGE','ECO_TAX_EFFICIENCY'],
    sources: ['World Bank WDI','IMF WEO','ILO','UNCTAD'],
  },
  PMIN: {
    name: 'Mineral Sovereignty',
    definition: 'Measures the degree to which a state captures the economic value of its mineral resources, controls extraction governance, and resists illicit financial flows from the mining sector.',
    indicators: ['MIN_RES','PMIN_VALUE_CAPTURE','PMIN_VALUE_LEAKAGE','MIN_LEAKAGE_RISK'],
    sources: ['USGS Mineral Yearbook','EITI','Comtrade HS 25-28','World Bank Pink Sheet'],
  },
  PHUM: {
    name: 'Human Sovereignty',
    definition: 'Measures the capacity of a state to ensure the fundamental conditions of human development — health, education, nutrition — for its population, independently of foreign aid dependency.',
    indicators: ['HUM_HDI','HUM_HEA_EXPENDITURE','HUM_EDU','PHUM_VALUE_CAPTURE'],
    sources: ['UNDP HDR','WHO','World Bank WDI'],
  },
  PENV: {
    name: 'Environmental Sovereignty',
    definition: 'Measures the capacity of a state to govern its natural environment, preserve biodiversity, and maintain territorial ecological integrity against external exploitation.',
    indicators: ['ENV_FOR','ENV_CO2','ENV_PROTECTED'],
    sources: ['FAO FRA','World Bank WDI','UNEP'],
  },
  PMIL: {
    name: 'Military Sovereignty',
    definition: 'Measures the autonomous defence capacity of a state — its ability to protect territorial integrity and maintain internal security without structural dependency on foreign military forces.',
    indicators: ['MIL_EXPENDITURE','MIL_PERSONNEL','MIL_EQUIPMENT'],
    sources: ['SIPRI Milex','World Bank WDI'],
  },
  PMON: {
    name: 'Monetary Sovereignty',
    definition: 'Measures the degree of control a state exercises over its monetary system — currency issuance, exchange rate management, and resistance to dollarisation or monetary subordination.',
    indicators: ['MON_RES','MON_IFF_PRESSURE','PMON_RESERVE_CAPTURE'],
    sources: ['IMF IFS','World Bank WDI','BIS'],
  },
  PNUM: {
    name: 'Digital Sovereignty',
    definition: 'Measures the capacity of a state to develop, govern, and protect its digital infrastructure and data assets independently of foreign technology dependency.',
    indicators: ['NUM_INTERNET','NUM_MOBILE','PNUM_DIGITAL_CAPTURE'],
    sources: ['ITU','World Bank WDI'],
  },
  PRES: {
    name: 'Energy Sovereignty',
    definition: 'Measures the capacity of a state to produce, distribute, and govern its energy resources autonomously, reducing dependency on imported fossil fuels.',
    indicators: ['RES_PRODUCTION','RES_ACCESS','RES_RENEWABLE'],
    sources: ['IEA','World Bank WDI','IRENA'],
  },
  PTRA: {
    name: 'Transport Sovereignty',
    definition: 'Measures the density, quality, and autonomy of a state transport infrastructure — roads, railways, ports, and aviation — as a vector of economic and territorial integration.',
    indicators: ['TRA_ROAD','TRA_RAIL','TRA_PORT','TRA_AIR'],
    sources: ['World Bank WDI','ITF','ICAO'],
  },
}

export default function Pillar() {
  const { code } = useParams()
  const pillar = PILLAR_DATA[code]

  if (!pillar) return (
    <div className="pillar-page">
      <p>Pillar not found : {code}</p>
      <Link to="/methodology">← Methodology</Link>
    </div>
  )

  return (
    <div className="pillar-page">
      <div className="pillar-header">
        <span className="pillar-code-badge">{code}</span>
        <h1 className="pillar-title">{pillar.name}</h1>
        <Link to="/methodology" className="back-link">← Methodology</Link>
      </div>

      <section className="pillar-section">
        <h2>Definition</h2>
        <p>{pillar.definition}</p>
      </section>

      <section className="pillar-section">
        <h2>Indicators</h2>
        <div className="indicators-list">
          {pillar.indicators.map(ind => (
            <span key={ind} className="indicator-tag">{ind}</span>
          ))}
        </div>
      </section>

      <section className="pillar-section">
        <h2>Data Sources</h2>
        <ul className="sources-list">
          {pillar.sources.map(src => (
            <li key={src}>{src}</li>
          ))}
        </ul>
      </section>

      <section className="pillar-section">
        <h2>Doctrine</h2>
        <p>This pillar follows the OSA P7E consequentialist doctrine : only observed, verifiable data is used. Perception-based indicators are excluded. Equal weighting is applied across active indicators with available data.</p>
      </section>
    </div>
  )
}
