import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getCountryScores, getCountryPillarScores, getCountryHistory } from '../api/scores'
import { getAmarAlert, getConflictEconomy } from '../api/alerts'
import ScoreTable from '../components/ScoreTable/ScoreTable'
import { useLang } from '../i18n/useLang'
import './Country.css'

const RISK_COLOR = {
  RED: '#B00020', ORANGE: '#E65100', YELLOW: '#F9A825', GREEN: '#1B5E20'
}

const RISK_LABEL = {
  en: { RED:'Critical', ORANGE:'Elevated', YELLOW:'Watchlist', GREEN:'Low' },
  fr: { RED:'Critique', ORANGE:'Élevé', YELLOW:'Surveillance', GREEN:'Faible' }
}

export default function Country() {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const [scores, setScores] = useState(null)
  const [pillarScores, setPillarScores] = useState(null)
  const [history, setHistory] = useState(null)
  const [amar, setAmar] = useState(null)
  const [conflict, setConflict] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    Promise.all([
      getCountryScores(iso3),
      getCountryPillarScores(iso3),
      getCountryHistory(iso3),
      getAmarAlert(iso3),
      getConflictEconomy(iso3),
    ])
      .then(([isa, pillars, hist, amarData, conflictData]) => {
        setScores(isa)
        setPillarScores(pillars)
        setHistory(hist)
        setAmar(amarData)
        setConflict(conflictData)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error) return <div className="page-error">{t('common.error')}: {error}</div>

  return (
    <div className="country-page">
      <div className="country-header">
        <h1 className="country-title">{iso3}</h1>
        <Link to="/countries" className="back-link">← {t('nav.countries')}</Link>
      </div>

      {(amar || conflict) && (
        <div className="country-alerts">
          {amar && (
            <div className="alert-card"
              style={{ borderColor: RISK_COLOR[amar.risk_band] || '#888' }}>
              <div className="alert-header">
                <span className="alert-badge"
                  style={{ background: RISK_COLOR[amar.risk_band] || '#888' }}>
                  AMAR — {RISK_LABEL[lang]?.[amar.risk_band] || amar.risk_band}
                </span>
                <span className="alert-year">2024</span>
              </div>
              <p className="alert-text">{amar.public_narrative}</p>
            </div>
          )}
          {conflict && (
            <div className="alert-card"
              style={{ borderColor: RISK_COLOR[conflict.risk_band] || '#888' }}>
              <div className="alert-header">
                <span className="alert-badge"
                  style={{ background: RISK_COLOR[conflict.risk_band] || '#888' }}>
                  {lang === 'fr' ? 'Économie de conflit' : 'Conflict Economy'} — {RISK_LABEL[lang]?.[conflict.risk_band] || conflict.risk_band}
                </span>
                <span className="alert-year">2024</span>
              </div>
              <p className="alert-text">{conflict.recommended_action}</p>
            </div>
          )}
        </div>
      )}

      <ScoreTable iso3={iso3} scoresData={scores} pillarData={pillarScores} historyData={history} />

      <div className="country-actions">
        <Link to={`/country/${iso3}/projects`} className="btn-projects">
          {t('table.projects')} →
        </Link>
      </div>
    </div>
  )
}
