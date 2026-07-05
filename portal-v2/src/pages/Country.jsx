import { useEffect, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { getCountryScores, getCountryPillarScores, getCountryHistory } from '../api/scores'
import { getAmarBadges, getConflictBadges } from '../api/alerts'
import { getStructuralObs } from '../api/structural'
import { getCountryIdentity } from '../api/countries'
import { useLang } from '../i18n/useLang'
import './Country.css'

const RISK_COLOR = {
  GREEN:  '#1A6B2A',
  YELLOW: '#C8973A',
  ORANGE: '#E65C00',
  RED:    '#B00020',
  BLACK:  '#1A1A1A',
}
const RISK_LABEL = {
  fr: { GREEN:'Faible', YELLOW:'Modéré', ORANGE:'Élevé', RED:'Critique', BLACK:'Extrême' },
  en: { GREEN:'Low', YELLOW:'Moderate', ORANGE:'High', RED:'Critical', BLACK:'Extreme' },
}
// Icônes de trajectoire -- reservées aux trajectoires REELLEMENT calculées.
// Deux vocabulaires distincts et VERIFIES en base le 3 juillet 2026 :
//   - Niveau pays  (pub.mv_isa_country_rankings.sovereign_trajectory) :
//     IMPROVING_TRAJECTORY, DECLINING_TRAJECTORY, MIXED_TRAJECTORY
//   - Niveau pilier (pub.mv_isa_pillar_breakdown.trajectory_class) :
//     ACCELERATING, PROGRESSING, STABLE, DECLINING, CRITICAL
// Aucune valeur "STABLE" n'existe au niveau pays, aucune valeur "IMPROVING"
// n'existe au niveau pilier -- ne jamais supposer un vocabulaire commun aux
// deux niveaux. L'absence de donnée n'est jamais rendue avec un de ces
// symboles : voir trajectoryDisplay() plus bas, qui distingue explicitement
// "aucune donnée" (texte "n/d" grisé) d'une trajectoire réellement calculée.
const TRAJ_ICON = {
  // Pays
  IMPROVING_TRAJECTORY: '↗',
  DECLINING_TRAJECTORY: '↘',
  MIXED_TRAJECTORY: '→',
  // Pilier
  ACCELERATING: '↗',
  PROGRESSING: '↗',
  STABLE: '→',
  DECLINING: '↘',
  CRITICAL: '↓',
}
const TRAJ_COLOR = {
  // Pays
  IMPROVING_TRAJECTORY: '#1A6B2A',
  DECLINING_TRAJECTORY: '#B00020',
  MIXED_TRAJECTORY: '#C8973A',
  // Pilier -- CRITICAL distingué de DECLINING (crise structurelle vs simple recul)
  ACCELERATING: '#1A6B2A',
  PROGRESSING: '#2E8B3A',
  STABLE: '#C8973A',
  DECLINING: '#B00020',
  CRITICAL: '#1A1A1A',
}
const PILLAR_NAMES = {
  fr: { PGEO:'Géopolitique', PECO:'Économique', PMIN:'Minière', PHUM:'Humaine',
        PENV:'Environnementale', PMIL:'Militaire', PMON:'Monétaire',
        PNUM:'Numérique', PRES:'Énergétique', PTRA:'Transport' },
  en: { PGEO:'Geopolitical', PECO:'Economic', PMIN:'Mineral', PHUM:'Human',
        PENV:'Environmental', PMIL:'Military', PMON:'Monetary',
        PNUM:'Digital', PRES:'Energy', PTRA:'Transport' },
}
const PILLAR_ORDER = ['PGEO','PECO','PMIN','PHUM','PENV','PMIL','PMON','PNUM','PRES','PTRA']

// Rend un trio {icon, color, label} pour une trajectoire, en distinguant
// explicitement "aucune donnée de trajectoire" de "trajectoire stable".
// A ne jamais remplacer par TRAJ_ICON[traj] || '—' -- le tiret et la flèche
// "→" de STABLE sont visuellement trop proches pour rester ambigus.
function trajectoryDisplay(traj, lang) {
  if (!traj) {
    return {
      icon: lang === 'fr' ? 'n/d' : 'n/a',
      color: 'var(--color-muted)',
      label: lang === 'fr' ? 'Aucune donnée de trajectoire' : 'No trajectory data',
      muted: true,
    }
  }
  return {
    icon: TRAJ_ICON[traj] || (lang === 'fr' ? 'n/d' : 'n/a'),
    color: TRAJ_COLOR[traj] || 'var(--color-muted)',
    label: null,
    muted: false,
  }
}

export default function Country() {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const navigate = useNavigate()
  const [scores, setScores]                   = useState(null)
  const [pillarScores, setPillarScores]       = useState(null)
  const [amarHistory, setAmarHistory]         = useState(null)
  const [conflictHistory, setConflictHistory] = useState(null)
  const [poaData, setPoaData]                 = useState(null)
  const [identity, setIdentity]               = useState(null)
  const [loading, setLoading]                 = useState(true)
  const [error, setError]                     = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    Promise.all([
      getCountryScores(iso3),
      getCountryPillarScores(iso3),
      getAmarBadges(iso3),
      getConflictBadges(iso3),
      getStructuralObs(iso3),
      getCountryIdentity(iso3),
    ])
      .then(([isa, pillars, amarData, conflictData, poa, id]) => {
        setScores(isa)
        setPillarScores(pillars)
        setAmarHistory(amarData)
        setConflictHistory(conflictData)
        setPoaData(poa)
        setIdentity(id)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error)   return <div className="page-error">{t('common.error')}: {error}</div>

  const countryName = identity ? (lang === 'fr' ? identity.name_fr : identity.name_en) : iso3
  const regionLabel = identity ? (lang === 'fr' ? identity.region_fr : identity.region_en) : null

  // ISA
  const latest    = scores?.[0]
  const isaScore  = latest ? parseFloat(latest.isa_observed_score).toFixed(3) : '—'
  const isaTraj   = trajectoryDisplay(latest?.sovereign_trajectory, lang)

  // POA -- compter les phenomenes (indicateurs distincts), pas les lignes
  // brutes (qui melangent plusieurs annees et plusieurs indicateurs de
  // couverture differente -- cf. finding GAF #31 POA_DOCTRINAL_TRANSITION)
  const poaCount = Array.isArray(poaData)
    ? new Set(poaData.map(o => o.indicator_code)).size
    : 0

  // GENECO
  const genecoBand  = conflictHistory?.[0]?.risk_band
  const genecoColor = RISK_COLOR[genecoBand] || '#888'
  const genecoLabel = RISK_LABEL[lang]?.[genecoBand] || genecoBand || '—'

  // AMAR
  const amarBand  = amarHistory?.[0]?.risk_band
  const amarColor = RISK_COLOR[amarBand] || '#888'
  const amarLabel = RISK_LABEL[lang]?.[amarBand] || amarBand || '—'

  // Piliers 2024
  const pillars2024 = pillarScores
    ? PILLAR_ORDER.map(code => {
        const row = pillarScores.find(p => p.pillar_code === code && p.year === 2024)
          || pillarScores.find(p => p.pillar_code === code)
        return { code, ...row }
      })
    : []

  return (
    <div className="country-page">

      {/* Header */}
      <div className="country-header">
        <div className="country-header-text">
          <h1 className="country-title">{countryName}</h1>
          {regionLabel && <span className="country-region">{regionLabel} · {iso3}</span>}
        </div>
        <Link to="/countries" className="back-link">← {t('nav.countries')}</Link>
      </div>

      {/* 4 cartouches */}
      <div className="country-products">

        {/* ISA */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">ISA</span>
            <span className="product-year">{latest?.year || 2024}</span>
          </div>
          <div className="product-card-body">
            <span className="product-score">{isaScore}</span>
            <span
              className="product-trajectory"
              style={{ color: isaTraj.color, fontStyle: isaTraj.muted ? 'italic' : 'normal', fontSize: isaTraj.muted ? '0.85rem' : undefined }}
              title={isaTraj.label || undefined}
            >
              {isaTraj.icon}
            </span>
          </div>
          <button className="product-btn product-btn--isa"
            onClick={() => navigate(`/country/${iso3}/isa`)}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* POA */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">POA</span>
          </div>
          <div className="product-card-body">
            <span className="product-score">{poaCount}</span>
          </div>
          <div className="product-card-sub">
            {lang === 'fr' ? 'phénomènes observés' : 'observed phenomena'}
          </div>
          <button className="product-btn product-btn--poa"
            onClick={() => navigate(`/country/${iso3}/poa`)}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* GENECO */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">GENECO</span>
          </div>
          <div className="product-card-body">
            <span className="product-badge" style={{ background: genecoColor }}>{genecoLabel}</span>
          </div>
          <div className="product-card-sub">
            {lang === 'fr' ? 'Économie de conflit' : 'Conflict economy'}
          </div>
          <button className="product-btn product-btn--geneco"
            onClick={() => navigate(`/country/${iso3}/conflict-economy`)}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* AMAR */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">AMAR</span>
          </div>
          <div className="product-card-body">
            <span className="product-badge" style={{ background: amarColor }}>{amarLabel}</span>
          </div>
          <div className="product-card-sub">
            {lang === 'fr' ? 'Vigilance souveraine' : 'Sovereign vigilance'}
          </div>
          <button className="product-btn product-btn--amar"
            onClick={() => navigate(`/country/${iso3}/amar`)}>
            {lang === 'fr' ? 'Alerte →' : 'Alert →'}
          </button>
        </div>

      </div>

      {/* 10 piliers */}
      <div className="country-pillars">
        <h2 className="country-pillars-title">
          {lang === 'fr' ? 'Les 10 piliers de la souveraineté' : 'The 10 sovereignty pillars'}
        </h2>
        {pillars2024.map(p => {
          const score = p.pillar_isa_score
          const traj  = p.trajectory_class || p.trajectory_signal
          const disp  = trajectoryDisplay(traj, lang)
          const name  = PILLAR_NAMES[lang]?.[p.code] || p.code
          return (
            <div key={p.code} className="pillar-row">
              <div className="pillar-row-left">
                <span className="pillar-row-code">{p.code}</span>
                <span className="pillar-row-name">{name}</span>
              </div>
              <div className="pillar-row-center">
                <span className="pillar-row-score">{score ? score.toFixed(3) : '—'}</span>
                <span
                  className="pillar-row-traj"
                  style={{ color: disp.color, fontStyle: disp.muted ? 'italic' : 'normal', fontSize: disp.muted ? '0.85rem' : undefined }}
                  title={disp.label || undefined}
                >
                  {disp.icon}
                </span>
              </div>
              <div className="pillar-row-actions">
                <button className="pillar-btn pillar-btn--analyse"
                  onClick={() => navigate(`/pillar/${p.code}?country=${iso3}`)}>
                  {lang === 'fr' ? 'Analyse →' : 'Analysis →'}
                </button>
              </div>
            </div>
          )
        })}
      </div>

    </div>
  )
}
