import { Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Pillars.css'

const PILLARS = [
  {
    code: 'PGEO',
    name: { fr: 'Souveraineté géopolitique',  en: 'Geopolitical Sovereignty' },
    short: { fr: 'Position diplomatique, influence internationale, exposition aux conflits.', en: 'Diplomatic position, international influence, conflict exposure.' },
    color: '#1A6B2A',
  },
  {
    code: 'PECO',
    name: { fr: 'Souveraineté économique',     en: 'Economic Sovereignty' },
    short: { fr: 'Capacité à générer, retenir et redistribuer la valeur en interne.', en: 'Capacity to generate, retain, and redistribute value internally.' },
    color: '#2E8B3A',
  },
  {
    code: 'PMIN',
    name: { fr: 'Souveraineté minière',        en: 'Mineral Sovereignty' },
    short: { fr: 'Captation de la valeur minérale, gouvernance extractive, flux illicites.', en: 'Mineral value capture, extractive governance, illicit flows.' },
    color: '#C8973A',
  },
  {
    code: 'PHUM',
    name: { fr: 'Souveraineté humaine',        en: 'Human Sovereignty' },
    short: { fr: 'Développement humain, rétention du capital, autonomie vis-à-vis de l\'aide.', en: 'Human development, capital retention, aid independence.' },
    color: '#1A6B2A',
  },
  {
    code: 'PENV',
    name: { fr: 'Souveraineté environnementale', en: 'Environmental Sovereignty' },
    short: { fr: 'Gouvernance de l\'environnement naturel, biodiversité, intégrité écologique.', en: 'Natural environment governance, biodiversity, ecological integrity.' },
    color: '#2E8B3A',
  },
  {
    code: 'PMIL',
    name: { fr: 'Souveraineté militaire',      en: 'Military Sovereignty' },
    short: { fr: 'Capacité de défense autonome, intégrité territoriale, sécurité intérieure.', en: 'Autonomous defence capacity, territorial integrity, internal security.' },
    color: '#C8973A',
  },
  {
    code: 'PMON',
    name: { fr: 'Souveraineté monétaire',      en: 'Monetary Sovereignty' },
    short: { fr: 'Contrôle du système monétaire, gestion du taux de change, résistance à la dollarisation.', en: 'Monetary system control, exchange rate management, dollarisation resistance.' },
    color: '#1A6B2A',
  },
  {
    code: 'PNUM',
    name: { fr: 'Souveraineté numérique',      en: 'Digital Sovereignty' },
    short: { fr: 'Infrastructure numérique, gouvernance des données, indépendance technologique.', en: 'Digital infrastructure, data governance, technology independence.' },
    color: '#2E8B3A',
  },
  {
    code: 'PRES',
    name: { fr: 'Souveraineté énergétique',    en: 'Energy Sovereignty' },
    short: { fr: 'Production et distribution énergétique autonome, transition vers les renouvelables.', en: 'Autonomous energy production and distribution, renewable transition.' },
    color: '#C8973A',
  },
  {
    code: 'PTRA',
    name: { fr: 'Souveraineté des transports', en: 'Transport Sovereignty' },
    short: { fr: 'Densité et qualité des infrastructures de transport, intégration territoriale.', en: 'Transport infrastructure density and quality, territorial integration.' },
    color: '#1A6B2A',
  },
]

export default function Pillars() {
  const { lang } = useLang()

  return (
    <div className="pillars-page">
      <div className="pillars-header">
        <h1 className="pillars-title">
          {lang === 'fr' ? 'Les 10 piliers de la souveraineté' : 'The 10 sovereignty pillars'}
        </h1>
        <p className="pillars-intro">
          {lang === 'fr'
            ? "L'ISA mesure la souveraineté africaine à travers 10 piliers comportementaux — chacun fondé sur des données primaires observées, auditables et reproductibles. Aucun indicateur perceptuel n'entre dans leur calcul."
            : "The ISA measures African sovereignty through 10 behavioural pillars — each grounded in observed, auditable, and reproducible primary data. No perceptual indicator enters their calculation."}
        </p>
      </div>

      <div className="pillars-grid">
        {PILLARS.map((p, i) => (
          <Link key={p.code} to={`/pillar/${p.code}`} className="pillar-card">
            <div className="pillar-card-top" style={{ borderLeftColor: p.color }}>
              <span className="pillar-card-index">{String(i + 1).padStart(2, '0')}</span>
              <span className="pillar-card-code">{p.code}</span>
            </div>
            <h2 className="pillar-card-name">{p.name[lang]}</h2>
            <p className="pillar-card-short">{p.short[lang]}</p>
            <span className="pillar-card-link">
              {lang === 'fr' ? 'Voir le pilier →' : 'View pillar →'}
            </span>
          </Link>
        ))}
      </div>
    </div>
  )
}
