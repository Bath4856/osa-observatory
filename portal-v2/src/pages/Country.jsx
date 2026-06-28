import { useEffect, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { getCountryScores, getCountryPillarScores } from '../api/scores'
import { getAmarBadges, getConflictBadges } from '../api/alerts'
import { getStructuralObs } from '../api/structural'
import { getCountryIdentity } from '../api/countries'
import { useLang } from '../i18n/useLang'
import './Country.css'

const RISK_COLOR = {
  GREEN:'#1A6B2A', YELLOW:'#C8973A', ORANGE:'#E65C00', RED:'#B00020', BLACK:'#1A1A1A',
}
const RISK_LABEL = {
  fr:{ GREEN:'Faible', YELLOW:'Modéré', ORANGE:'Élevé', RED:'Critique', BLACK:'Extrême' },
  en:{ GREEN:'Low', YELLOW:'Moderate', ORANGE:'High', RED:'Critical', BLACK:'Extreme' },
}
const TRAJ_ICON  = { DECLINING:'↘', IMPROVING:'↗', STABLE:'→', DECLINING_TRAJECTORY:'↘', IMPROVING_TRAJECTORY:'↗', STABLE_TRAJECTORY:'→' }
const TRAJ_COLOR = { DECLINING:'#B00020', IMPROVING:'#1A6B2A', STABLE:'#C8973A', DECLINING_TRAJECTORY:'#B00020', IMPROVING_TRAJECTORY:'#1A6B2A', STABLE_TRAJECTORY:'#C8973A' }
const PILLAR_NAMES = {
  fr:{ PGEO:'Géopolitique', PECO:'Économique', PMIN:'Minière', PHUM:'Humaine', PENV:'Environnementale', PMIL:'Militaire', PMON:'Monétaire', PNUM:'Numérique', PRES:'Énergétique', PTRA:'Transport' },
  en:{ PGEO:'Geopolitical', PECO:'Economic', PMIN:'Mineral', PHUM:'Human', PENV:'Environmental', PMIL:'Military', PMON:'Monetary', PNUM:'Digital', PRES:'Energy', PTRA:'Transport' },
}
const PILLAR_ORDER = ['PGEO','PECO','PMIN','PHUM','PENV','PMIL','PMON','PNUM','PRES','PTRA']

const PRODUCT_DESC = {
  ISA:    { fr:'Évaluer la souveraineté.', en:'Evaluate sovereignty.' },
  IOSA:   { fr:'Observer les phénomènes souverains ayant une matérialité mesurable.', en:'Observe sovereign phenomena with measurable materiality.' },
  GENECO: { fr:"Détecter les mécanismes économiques susceptibles de fragiliser durablement l'exercice de la souveraineté dans un contexte de conflit.", en:'Detect economic mechanisms likely to durably undermine sovereignty in a conflict context.' },
  AMAR:   { fr:'Identifier les situations nécessitant une vigilance renforcée.', en:'Identify situations requiring enhanced vigilance.' },
}

export default function Country() {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const navigate = useNavigate()
  const [scores, setScores]                   = useState(null)
  const [pillarScores, setPillarScores]       = useState(null)
  const [amarHistory, setAmarHistory]         = useState(null)
  const [conflictHistory, setConflictHistory] = useState(null)
  const [iosaData, setIosaData]               = useState(null)
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
      .then(([isa, pillars, amarData, conflictData, iosa, id]) => {
        setScores(isa)
        setPillarScores(pillars)
        setAmarHistory(amarData)
        setConflictHistory(conflictData)
        setIosaData(iosa)
        setIdentity(id)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error)   return <div className="page-error">{t('common.error')}: {error}</div>

  const countryName = identity ? (lang === 'fr' ? identity.name_fr : identity.name_en) : iso3
  const regionLabel = identity ? (lang === 'fr' ? identity.region_fr : identity.region_en) : null

  const latest    = scores?.[0]
  const isaScore  = latest ? parseFloat(latest.isa_observed_score).toFixed(3) : '—'
  const isaRank   = latest?.isa_position
  const trajectory = latest?.sovereign_trajectory
  const trajIcon  = TRAJ_ICON[trajectory] || '→'
  const trajColor = TRAJ_COLOR[trajectory] || '#888'

  const iosaCount = Array.isArray(iosaData) ? iosaData.filter(o => o.year === 2024).length : 0

  const geneco2024  = conflictHistory?.find(h => h.year === 2024) || conflictHistory?.[0]
  const genecoBand  = geneco2024?.risk_band
  const genecoColor = RISK_COLOR[genecoBand] || '#888'
  const genecoLabel = RISK_LABEL[lang]?.[genecoBand] || genecoBand || '—'

  const amar2024  = amarHistory?.find(h => h.year === 2024) || amarHistory?.[0]
  const amarBand  = amar2024?.risk_band
  const amarColor = RISK_COLOR[amarBand] || '#888'
  const amarLabel = RISK_LABEL[lang]?.[amarBand] || amarBand || '—'

  const allPillars = Array.isArray(pillarScores) ? pillarScores : (pillarScores?.data || [])
  const pillars2024 = PILLAR_ORDER.map(code => {
    const row = allPillars.find(p => p.pillar_code === code && p.year === 2024)
            || allPillars.find(p => p.pillar_code === code)
    return { code, ...row }
  })

  return (
    <div className="country-page">

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
          <p className="product-desc">{PRODUCT_DESC.ISA[lang]}</p>
          <div className="product-card-body">
            <span className="product-score">{isaScore}</span>
            <span className="product-trajectory" style={{ color: trajColor }}>{trajIcon}</span>
          </div>
          {isaRank && <div className="product-card-sub">{lang === 'fr' ? `Rang : ${isaRank}/54` : `Rank: ${isaRank}/54`}</div>}
          <button className="product-btn product-btn--isa" onClick={() => navigate(`/country/${iso3}/isa`)}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* IOSA */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">IOSA</span>
          </div>
          <p className="product-desc">{PRODUCT_DESC.IOSA[lang]}</p>
          <div className="product-card-body">
            <span className="product-score">{iosaCount}</span>
          </div>
          <div className="product-card-sub">{lang === 'fr' ? 'observations souveraines' : 'sovereign observations'}</div>
          <button className="product-btn product-btn--iosa" onClick={() => navigate(`/country/${iso3}/iosa`)}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* GENECO */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">GENECO</span>
          </div>
          <p className="product-desc">{PRODUCT_DESC.GENECO[lang]}</p>
          <div className="product-card-body">
            <span className="product-badge" style={{ background: genecoColor }}>{genecoLabel}</span>
          </div>
          <div className="product-card-sub">{lang === 'fr' ? 'Économie de conflit' : 'Conflict economy'}</div>
          <button className="product-btn product-btn--geneco" onClick={() => navigate(`/country/${iso3}/conflict-economy`)}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* AMAR */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">AMAR</span>
          </div>
          <p className="product-desc">{PRODUCT_DESC.AMAR[lang]}</p>
          <div className="product-card-body">
            <span className="product-badge" style={{ background: amarColor }}>{amarLabel}</span>
          </div>
          <div className="product-card-sub">{lang === 'fr' ? 'Vigilance souveraine' : 'Sovereign vigilance'}</div>
          <button className="product-btn product-btn--amar" onClick={() => navigate(`/country/${iso3}/amar`)}>
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
          const icon  = TRAJ_ICON[traj] || '—'
          const color = TRAJ_COLOR[traj] || '#888'
          const name  = PILLAR_NAMES[lang]?.[p.code] || p.code
          return (
            <div key={p.code} className="pillar-row">
              <div className="pillar-row-left">
                <span className="pillar-row-code">{p.code}</span>
                <span className="pillar-row-name">{name}</span>
              </div>
              <div className="pillar-row-center">
                <span className="pillar-row-score">{score ? score.toFixed(3) : '—'}</span>
                <span className="pillar-row-traj" style={{ color }}>{icon}</span>
              </div>
              <div className="pillar-row-actions">
                <button className="pillar-btn pillar-btn--analyse" onClick={() => navigate(`/pillar/${p.code}`)}>
                  {lang === 'fr' ? 'Analyse' : 'Analysis'}
                </button>
                <button className="pillar-btn pillar-btn--projects" onClick={() => navigate(`/country/${iso3}/projects?pillar=${p.code}`)}>
                  {lang === 'fr' ? 'Projets structurants' : 'Structural projects'}
                </button>
              </div>
            </div>
          )
        })}
      </div>

    </div>
  )
}
