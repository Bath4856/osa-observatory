import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useLang } from '../../i18n/useLang'
import './ScoreTable.css'

const PILLARS = ['PGEO','PECO','PMIN','PHUM','PENV','PMIL','PMON','PNUM','PRES','PTRA']

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

export default function ScoreTable({ iso3, scoresData, pillarData }) {
  const { t } = useLang()
  const navigate = useNavigate()

  const allYears = Array.from({ length: 20 }, (_, i) => 2010 + i)

  // Annee max disponible dans les donnees
  const maxDataYear = scoresData && scoresData.length > 0
    ? Math.max(...scoresData.map(d => d.year))
    : 2024

  // Fenetre glissante : 5 ans se terminant a maxDataYear
  const defaultEnd = Math.min(maxDataYear, 2029)
  const defaultStart = defaultEnd - 4
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
    return entry ? entry.strength_score : null
  }

  const getTraj = (year) => {
    if (!scoresData) return null
    const entry = scoresData.find(d => d.year === year)
    if (!entry) return null
    const t = entry.sovereign_trajectory
    if (!t) return null
    if (t.includes('IMPROVING')) return '↗'
    if (t.includes('DECLINING')) return '↘'
    return '→'
  }

  return (
    <div className="score-table-wrapper">
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
                <th key={y} className="col-year"
                  style={{ color: STATUS_COLOR[st] }}>
                  {y}{st === 'COLLECTING' ? ' ○' : ''}
                </th>
              )
            })}
            <th className="col-action"></th>
          </tr>
        </thead>
        <tbody>
          <tr className="row-isa">
            <td className="cell-label">ISA</td>
            {windowYears.map(y => {
              const st = getStatus(y)
              const val = getISA(y)
              return (
                <td key={y} className={`cell-score ${st === 'COLLECTING' ? 'collecting' : ''}`}
                  style={{ color: STATUS_COLOR[st] }}>
                  {fmt(val, st)}
                </td>
              )
            })}
            <td></td>
          </tr>

          {PILLARS.map(pillar => (
            <tr key={pillar} className="row-pillar">
              <td className="cell-label">{pillar}</td>
              {windowYears.map(y => {
                const st = getStatus(y)
                const val = getPillar(pillar, y)
                return (
                  <td key={y} className={`cell-score ${st === 'COLLECTING' ? 'collecting' : ''}`}
                    style={{ color: STATUS_COLOR[st] }}>
                    {fmt(val, st)}
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

          <tr className="row-trajectory">
            <td className="cell-label">{t('table.trajectory')}</td>
            {windowYears.map(y => {
              const st = getStatus(y)
              const traj = getTraj(y)
              return (
                <td key={y} className={`cell-score ${st === 'COLLECTING' ? 'collecting' : ''}`}>
                  {st === 'COLLECTING' ? '—' : (traj || '—')}
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
        </tbody>
      </table>
    </div>
  )
}
