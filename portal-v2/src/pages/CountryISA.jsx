import { useEffect, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { getCountryScores, getCountryPillarScores, getCountryHistory } from '../api/scores'
import { getAmarBadges, getConflictBadges } from '../api/alerts'
import { getStructuralObs } from '../api/structural'
import { getCountryIdentity } from '../api/countries'
import ScoreTable from '../components/ScoreTable/ScoreTable'
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
  en: { GREEN:'Low',    YELLOW:'Moderate', ORANGE:'High', RED:'Critical', BLACK:'Extreme' },
}
const TRAJECTORY_ICON = {
  DECLINING_TRAJECTORY:  '↘',
  IMPROVING_TRAJECTORY:  '↗',
  STABLE_TRAJECTORY:     '→',
  ACCELERATING_DECLINE:  '↓↓',
  ACCELERATING_RECOVERY: '↑↑',
}
const TRAJECTORY_COLOR = {
  DECLINING_TRAJECTORY:  '#B00020',
  IMPROVING_TRAJECTORY:  '#1A6B2A',
  STABLE_TRAJECTORY:     '#C8973A',
  ACCELERATING_DECLINE:  '#B00020',
  ACCELERATING_RECOVERY: '#1A6B2A',
}

export default function Country() {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const navigate = useNavigate()
  const [scores, setScores]           = useState(null)
  const [pillarScores, setPillarScores] = useState(null)
  const [history, setHistory]         = useState(null)
  const [amarHistory, setAmarHistory] = useState(null)
  const [conflictHistory, setConflictHistory] = useState(null)
  const [iosaData, setIosaData]       = useState(null)
  const [identity, setIdentity]       = useState(null)
  const [loading, setLoading]         = useState(true)
  const [error, setError]             = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    Promise.all([
      getCountryScores(iso3),
      getCountryPillarScores(iso3),
      getCountryHistory(iso3),
      getAmarBadges(iso3),
      getConflictBadges(iso3),
      getStructuralObs(iso3),
      getCountryIdentity(iso3),
    ])
      .then(([isa, pillars, hist, amarData, conflictData, iosa, id]) => {
        setScores(isa)
        setPillarScores(pillars)
        setHistory(hist)
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

  const countryName  = identity ? (lang === 'fr' ? identity.name_fr : identity.name_en) : iso3
  const regionLabel  = identity ? (lang === 'fr' ? identity.region_fr : identity.region_en) : null

  // ISA cartouche
  const latest       = scores?.history?.[0]
  const isaScore     = latest ? parseFloat(latest.isa_observed_score).toFixed(3) : '—'
  const trajectory   = latest?.sovereign_trajectory
  const trajIcon     = trajectory ? (TRAJECTORY_ICON[trajectory] || '→') : '—'
  const trajColor    = trajectory ? (TRAJECTORY_COLOR[trajectory] || '#888') : '#888'
  const isaRank      = latest?.isa_position

  // IOSA cartouche
  const iosaCount    = Array.isArray(iosaData) ? iosaData.length : 0

  // GENECO cartouche
  const genecoBand   = conflictHistory?.[0]?.risk_band
  const genecoColor  = genecoBand ? (RISK_COLOR[genecoBand] || '#888') : '#888'
  const genecoLabel  = genecoBand ? (RISK_LABEL[lang]?.[genecoBand] || genecoBand) : '—'

  // AMAR cartouche
  const amarBand     = amarHistory?.[0]?.risk_band
  const amarColor    = amarBand ? (RISK_COLOR[amarBand] || '#888') : '#888'
  const amarLabel    = amarBand ? (RISK_LABEL[lang]?.[amarBand] || amarBand) : '—'

  return (
    <div className="country-page">

      {/* Header */}
      <div className="country-header">
        <div className="country-header-text">
          <h1 className="country-title">{countryName}</h1>
          {regionLabel && (
            <span className="country-region">{regionLabel} · {iso3}</span>
          )}
        </div>
        <Link to="/countries" className="back-link">← {t('nav.countries')}</Link>
      </div>

      {/* 4 cartouches produits */}
      <div className="country-products">

        {/* ISA */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">ISA</span>
            <span className="product-year">{latest?.year || 2024}</span>
          </div>
          <div className="product-card-body">
            <span className="product-score">{isaScore}</span>
            <span className="product-trajectory" style={{ color: trajColor }}>
              {trajIcon}
            </span>
          </div>
          {isaRank && (
            <div className="product-card-sub">
              {lang === 'fr' ? `Rang continental : ${isaRank}/54` : `Continental rank: ${isaRank}/54`}
            </div>
          )}
          <button className="product-btn product-btn--isa"
            onClick={() => document.getElementById('score-table')?.scrollIntoView({ behavior: 'smooth' })}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* IOSA */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">IOSA</span>
          </div>
          <div className="product-card-body">
            <span className="product-score">{iosaCount}</span>
          </div>
          <div className="product-card-sub">
            {lang === 'fr' ? 'observations souveraines' : 'sovereign observations'}
          </div>
          <button className="product-btn product-btn--iosa"
            onClick={() => navigate(`/country/${iso3}/iosa`)}>
            {lang === 'fr' ? 'Détail →' : 'Detail →'}
          </button>
        </div>

        {/* GENECO */}
        <div className="product-card">
          <div className="product-card-header">
            <span className="product-code">GENECO</span>
          </div>
          <div className="product-card-body">
            <span className="product-badge" style={{ background: genecoColor }}>
              {genecoLabel}
            </span>
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
            <span className="product-badge" style={{ background: amarColor }}>
              {amarLabel}
            </span>
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

      {/* Tableau ISA détaillé */}
      <div id="score-table">
        <ScoreTable
          iso3={iso3}
          scoresData={scores}
          pillarData={pillarScores}
          historyData={history}
          amarData={amarHistory}
          conflictData={conflictHistory}
          iosaData={iosaData}
          identity={identity}
        />
      </div>

    </div>
  )
}
