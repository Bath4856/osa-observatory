import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useLang } from '../../i18n/useLang'
import './ScoreTable.css'

const PILLARS = ['PGEO','PECO','PMIN','PHUM','PENV','PMIL','PMON','PNUM','PRES','PTRA']

const PUBLICATION_STATUS = {
  OFFICIAL:    { label: 'OFFICIAL',    color: '#1B5E20' },
  PRELIMINARY: { label: 'PRELIMINARY', color: '#7D4800' },
  COLLECTING:  { label: 'COLLECTING',  color: '#AAAAAA' },
}

function getStatus(year) {
  if (year <= 2024) return 'OFFICIAL'
  if (year <= 2026) return 'COLLECTING'
  return 'COLLECTING'
}

function formatScore(val, status) {
  if (status === 'COLLECTING') return '—'
  if (val === null || val === undefined) return '—'
  return typeof val === 'number' ? val.toFixed(2) : val
}

export default function ScoreTable({ iso3, scoresData }) {
  const { t } = useLang()
  const navigate = useNavigate()

  const allYears = Array.from({ length: 20 }, (_, i) => 2010 + i)
  const [windowStart, setWindowStart] = useState(2020)

  const windowYears = allYears.filter(y => y >= windowStart && y < windowStart + 5)

  const canPrev = windowStart > 2010
  const canNext = windowStart + 5 <= 2029

  const getScore = (indicator, year) => {
    if (!scoresData) return null
    const entry = scoresData.find(d => d.year === year)
    if (!entry) return null
    if (indicator === 'ISA') return entry.isa_score ?? entry.score ?? null
    return entry[indicator.toLowerCase()] ?? entry.pillars?.[indicator] ?? null
  }

  const getISAScore = (year) => {
    if (!scoresData) return null
    const entry = scoresData.find(d => d.year === year)
    if (!entry) return null
    return entry.isa_score ?? entry.score ?? null
  }

  return (
    <div className="score-table-wrapper">
      <div className="year-nav">
        <button
          className="year-nav-btn"
          onClick={() => setWindowStart(s => s - 5)}
          disabled={!canPrev}>← {windowStart - 5}–{windowStart - 1}</button>
        <span className="year-nav-range">{windowStart}–{windowStart + 4}</span>
        <button
          className="year-nav-btn"
          onClick={() => setWindowStart(s => s + 5)}
          disabled={!canNext}>{windowStart + 5}–{windowStart + 9} →</button>
      </div>

      <table className="score-table">
        <thead>
          <tr>
            <th className="col-indicator">{t('table.indicator')}</th>
            {windowYears.map(y => {
              const st = getStatus(y)
              return (
                <th key={y} className="col-year" style={{ color: PUBLICATION_STATUS[st].color }}>
                  {y}
                  <span className="year-status">{st === 'COLLECTING' ? ' ○' : ''}</span>
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
              const val = getISAScore(y)
              return (
                <td key={y} className={`cell-score ${st === 'COLLECTING' ? 'collecting' : ''}`}
                  style={{ color: PUBLICATION_STATUS[st].color }}>
                  {formatScore(val, st)}
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
                const val = getScore(pillar, y)
                return (
                  <td key={y} className={`cell-score ${st === 'COLLECTING' ? 'collecting' : ''}`}
                    style={{ color: PUBLICATION_STATUS[st].color }}>
                    {formatScore(val, st)}
                  </td>
                )
              })}
              <td className="cell-action">
                <button
                  className="btn-pillar"
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
              return (
                <td key={y} className={`cell-score ${st === 'COLLECTING' ? 'collecting' : ''}`}>
                  {st === 'COLLECTING' ? '—' : '↗'}
                </td>
              )
            })}
            <td className="cell-action">
              <button
                className="btn-pillar"
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
