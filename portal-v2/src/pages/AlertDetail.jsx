import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getAmarAlert, getConflictEconomy } from '../api/alerts'
import { useLang } from '../i18n/useLang'
import { RISK_COLOR, RISK_LABEL } from '../constants/risk'
import './AlertDetail.css'

const DIMENSION_LABELS = {
  resource_capture_risk:        { en: 'Resource capture',        fr: 'Captation de ressources' },
  logistics_enabling_risk:      { en: 'Logistics enabling',      fr: 'Facilitation logistique' },
  institutional_capture_risk:   { en: 'Institutional capture',   fr: 'Captation institutionnelle' },
  civilian_exploitation_risk:   { en: 'Civilian exploitation',   fr: 'Exploitation civile' },
  narrative_weaponization_risk: { en: 'Narrative weaponization', fr: 'Instrumentalisation narrative' },
}

export default function AlertDetail({ type }) {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const isAmar = type === 'amar'
  const title = isAmar ? 'AMAR' : (lang === 'fr' ? 'Économie de conflit' : 'Conflict economy')

  useEffect(() => {
    setLoading(true)
    setError(null)
    const fetcher = isAmar ? getAmarAlert(iso3) : getConflictEconomy(iso3)
    fetcher
      .then(d => setData(d))
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3, type])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error) return <div className="page-error">{t('common.error')}: {error}</div>

  return (
    <div className="alert-detail-page">
      <div className="alert-detail-header">
        <h1 className="alert-detail-title">{title} — {iso3}</h1>
        <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
      </div>

      {!data && (
        <p className="alert-detail-empty">
          {lang === 'fr' ? 'Aucune donnée disponible pour ce pays.' : 'No data available for this country.'}
        </p>
      )}

      {data && (
        <div className="alert-detail-card" style={{ borderColor: RISK_COLOR[data.risk_band] || '#888' }}>
          <div className="alert-detail-top">
            <span className="risk-badge-lg" style={{ background: RISK_COLOR[data.risk_band] || '#888' }}>
              {RISK_LABEL[lang]?.[data.risk_band] || data.risk_band}
            </span>
            <span className="alert-detail-year">{data.year}</span>
          </div>

          <p className="alert-detail-narrative">
            {isAmar ? data.public_narrative : data.recommended_action}
          </p>

          {!isAmar && (
            <div className="alert-detail-dimensions">
              {Object.keys(DIMENSION_LABELS).map(key => (
                data[key] !== undefined && (
                  <div key={key} className="dimension-row">
                    <span className="dimension-label">{DIMENSION_LABELS[key][lang]}</span>
                    <div className="dimension-bar-track">
                      <div className="dimension-bar-fill" style={{ width: `${Math.round(data[key] * 100)}%` }} />
                    </div>
                    <span className="dimension-value">{data[key].toFixed(2)}</span>
                  </div>
                )
              ))}
            </div>
          )}

          <p className="alert-detail-disclaimer">
            {isAmar ? t('table.legend') : data.public_disclaimer}
          </p>
        </div>
      )}
    </div>
  )
}