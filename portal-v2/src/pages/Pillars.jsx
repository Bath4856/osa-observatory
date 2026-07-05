import { Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import { PILLAR_ORDER, PILLAR_DATA } from '../data/pillarData'
import './Pillars.css'

export default function Pillars() {
  const { lang } = useLang()

  return (
    <div className="pillars-page">
      <div className="pillars-header">
        <h1 className="pillars-title">
          {lang === 'fr' ? 'Les 10 piliers de la souveraineté' : 'The 10 Sovereignty Pillars'}
        </h1>
        <p className="pillars-intro">
          {lang === 'fr'
            ? "Chaque pilier mesure une dimension comportementale distincte de la souveraineté africaine, à partir de données primaires, auditables et non-perceptuelles."
            : "Each pillar measures a distinct behavioural dimension of African sovereignty, from primary, auditable and non-perceptual data."}
        </p>
      </div>

      <div className="pillars-grid">
        {PILLAR_ORDER.map((code, i) => {
          const pillar = PILLAR_DATA[code]
          if (!pillar) return null
          return (
            <Link key={code} to={`/pillar/${code}`} className="pillar-card">
              <div className="pillar-card-top">
                <span className="pillar-card-index">{String(i + 1).padStart(2, '0')}</span>
                <span className="pillar-card-code">{code}</span>
              </div>
              <h2 className="pillar-card-name">{pillar.name[lang]}</h2>
              <p className="pillar-card-short">{pillar.definition[lang]}</p>
              <span className="pillar-card-link">
                {lang === 'fr' ? 'Voir le détail →' : 'View details →'}
              </span>
            </Link>
          )
        })}
      </div>
    </div>
  )
}
