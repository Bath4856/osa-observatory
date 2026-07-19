import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useLang } from '../../i18n/useLang'
import { RISK_COLOR, RISK_LABEL } from '../../constants/risk'
import './ScoreTable.css'

const PILLARS = ['PGEO','PECO','PMIN','PHUM','PENV','PMIL','PMON','PNUM','PRES','PTRA']

const PILLAR_LABELS = {
  PGEO:{en:'Geopolitical',fr:'Géopolitique'},
  PECO:{en:'Economic',fr:'Économique'},
  PMIN:{en:'Mineral',fr:'Minière'},
  PHUM:{en:'Human',fr:'Humaine'},
  PENV:{en:'Environmental',fr:'Environnementale'},
  PMIL:{en:'Military',fr:'Militaire'},
  PMON:{en:'Monetary',fr:'Monétaire'},
  PNUM:{en:'Digital',fr:'Numérique'},
  PRES:{en:'Energy',fr:'Énergétique'},
  PTRA:{en:'Transport',fr:'Transport'}
}

const DIRECTION_ICON = {
  IMPROVING:    '↗',
  STABLE:       '→',
  DETERIORATING:'↘',
}

const STATUS_COLOR = {
  OFFICIAL:    '#1B5E20',
  PRELIMINARY: '#7D4800',
  COLLECTING:  '#AAAAAA',
}

function getStatus(year) {
  if (year <= 2024) return 'OFFICIAL'
  return 'COLLECTING'
}

function fmt(val, status) {
  if (status === 'COLLECTING') return '—'
  if (val === null || val === undefined) return '—'
  const n = parseFloat(val)
  return isNaN(n) ? '—' : n.toFixed(3)
}

export default function ScoreTable({ iso3, scoresData, pillarData, historyData, amarData, conflictData, poaData }) {
  const { t, lang } = useLang()
  const navigate = useNavigate()

  const allYears = Array.from({ length: 20 }, (_, i) => 2010 + i)
  const maxDataYear = scoresData && scoresData.length > 0
    ? Math.max(...scoresData.map(d => d.year)) : 2024
  const defaultEnd = Math.min(maxDataYear, 2029)
  const [windowEnd, setWindowEnd] = useState(defaultEnd)
  const windowStart = windowEnd - 4
  const canPrev = windowStart > 2010
  const canNext = windowEnd < 2029
  const windowYears = allYears.filter(y => y >= windowStart && y <= windowEnd)

  const getISA = (year) => {
    if (!scoresData) return null
    const entry = scoresData.find(d => d.year === year)
    return entry ? entry.isa_observed_score : null
  }

  const getPillar = (pillarCode, year) => {
    if (!pillarData) return null
    const entry = pillarData.find(d => d.pillar_code === pillarCode && d.year === year)
    return entry ? entry.pillar_isa_score : null
  }

  const getTraj = (year) => {
    if (year <= 2020) return null
    if (!historyData) return null
    const entry = historyData.find(d => d.year === year)
    if (!entry || !entry.annual_direction) return null
    return DIRECTION_ICON[entry.annual_direction] || '→'
  }

  const getAmarYear = (year) => {
    if (!amarData) return null
    return amarData.find(d => d.year === year) || null
  }

  const getConflictYear = (year) => {
    if (!conflictData) return null
    return conflictData.find(d => d.year === year) || null
  }

  // Nombre d'observations POA distinctes pour une année donnée
  const getPoaCount = (year) => {
    if (!poaData || poaData.length === 0) return 0
    return [...new Set(poaData.filter(d => d.year === year).map(d => d.indicator_code))].length
  }

  // Indicateur de présence POA globale (au moins une observation dans la fenêtre)
  const hasPoa = poaData && poaData.length > 0

  const RiskBadge = ({ band }) => (
    <span className="risk-badge" style={{ background: RISK_COLOR[band] || '#888' }}>
      {RISK_LABEL[lang]?.[band] || band}
    </span>
  )

  return (
    <div className="score-table-wrapper">
      <div className="score-legend">{t('table.legend')}</div>
      <div className="year-nav">
        <button className="year-nav-btn"
          onClick={() => setWindowEnd(e => e - 1)}
          disabled={!canPrev}>← {windowStart - 1}</button>
        <span className="year-nav-range">{windowStart}–{windowEnd}</span>
        <button className="year-nav-btn"
          onClick={() => setWindowEnd(e => e + 1)}
          disabled={!canNext}>{windowEnd + 1} →</button>
      </div>
      <table className="score-table">
        <thead>
          <tr>
            <th className="col-indicator">{t('table.indicator')}</th>
            {windowYears.map(y => {
              const st = getStatus(y)
              return (
                <th key={y} className="col-year" style={{ color: STATUS_COLOR[st] }}>
                  {y}{st === 'COLLECTING' ? ' ○' : ''}
                </th>
              )
            })}
            <th className="col-action"></th>
          </tr>
        </thead>
        <tbody>
          {/* ISA */}
          <tr className="row-isa">
            <td className="cell-label">ISA</td>
            {windowYears.map(y => {
              const st = getStatus(y)
              return (
                <td key={y} className={`cell-score ${st==='COLLECTING'?'collecting':''}`}
                  style={{ color: STATUS_COLOR[st] }}>
                  {fmt(getISA(y), st)}
                </td>
              )
            })}
            <td className="cell-action">
              <button className="btn-pillar"
                onClick={() => navigate(`/country/${iso3}/projects`)}>
                →
              </button>
            </td>
          </tr>



          {/* Trajectoire */}
          <tr className="row-trajectory">
            <td className="cell-label">{t('table.trajectory')}</td>
            {windowYears.map(y => {
              const st = getStatus(y)
              const traj = getTraj(y)
              return (
                <td key={y} className={`cell-score ${st==='COLLECTING'?'collecting':''}`}>
                  {st === 'COLLECTING' ? '—' : (traj || '—')}
                </td>
              )
            })}
            <td></td>
          </tr>
          {/* 10 piliers */}
          {PILLARS.map(pillar => (
            <tr key={pillar} className="row-pillar">
              <td className="cell-label">
                <span className="pillar-code">{pillar}</span>
                <span className="pillar-label">{PILLAR_LABELS[pillar][lang]}</span>
              </td>
              {windowYears.map(y => {
                const st = getStatus(y)
                return (
                  <td key={y} className={`cell-score ${st==='COLLECTING'?'collecting':''}`}
                    style={{ color: STATUS_COLOR[st] }}>
                    {fmt(getPillar(pillar, y), st)}
                  </td>
                )
              })}
              <td className="cell-action">
                <button className="btn-pillar"
                  onClick={() => navigate(`/country/${iso3}/projects?pillar=${pillar}`)}>
                  →
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
