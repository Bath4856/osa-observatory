import { useEffect, useState } from 'react'
import { useLang } from '../i18n/useLang'
import { getOpportunities } from '../api/osoa'
import './OsoaOpportunities.css'

const STATUS_LABEL = {
  ACTIVE:    { fr: 'Active',    en: 'Active' },
  CLOSED:    { fr: 'Clôturée',  en: 'Closed' },
  ABANDONED: { fr: 'Abandonnée', en: 'Abandoned' },
}

const ORIGIN_LABEL = {
  INTERNAL: { fr: 'Interne (OIM)', en: 'Internal (OIM)' },
  EXTERNAL: { fr: 'Externe',       en: 'External' },
}

const PARTICIPATION_LABEL = {
  PROVIDER:            { fr: 'Prestataire',            en: 'Provider' },
  CONSORTIUM_PARTNER:  { fr: 'Partenaire consortium',  en: 'Consortium partner' },
  WATCH_ONLY:          { fr: 'Veille',                 en: 'Watch only' },
}

export default function OsoaOpportunities() {
  const { lang } = useLang()
  const [items, setItems] = useState(null)
  const [disclaimer, setDisclaimer] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [statusFilter, setStatusFilter] = useState('')
  const [originFilter, setOriginFilter] = useState('')

  useEffect(() => {
    setLoading(true)
    setError(null)
    getOpportunities({ status: statusFilter || undefined, origin_type: originFilter || undefined })
      .then(d => {
        setItems(d.items || [])
        setDisclaimer(d.disclaimer || null)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [statusFilter, originFilter])

  const t = (fr, en) => (lang === 'fr' ? fr : en)

  return (
    <div className="osoa-opp-page">
      <div className="osoa-opp-header">
        <span className="osoa-opp-eyebrow">OSOA</span>
        <h1 className="osoa-opp-title">{t('Opportunités', 'Opportunities')}</h1>
        <p className="osoa-opp-subtitle">
          {t(
            "Pipeline des dossiers d'engagement examinés par l'OSA — appels d'offres, manifestations d'intérêt et demandes de proposition, internes ou externes.",
            'Pipeline of engagement dossiers examined by OSA — tenders, expressions of interest and requests for proposal, internal or external.'
          )}
        </p>
      </div>

      <div className="osoa-opp-filters">
        <div className="osoa-opp-filter-group">
          <span className="osoa-opp-filter-label">{t('Statut', 'Status')}</span>
          {['', 'ACTIVE', 'CLOSED', 'ABANDONED'].map(s => (
            <button
              key={s || 'all'}
              className={`osoa-opp-pill ${statusFilter === s ? 'is-active' : ''}`}
              onClick={() => setStatusFilter(s)}
            >
              {s ? STATUS_LABEL[s][lang] : t('Toutes', 'All')}
            </button>
          ))}
        </div>
        <div className="osoa-opp-filter-group">
          <span className="osoa-opp-filter-label">{t('Origine', 'Origin')}</span>
          {['', 'INTERNAL', 'EXTERNAL'].map(o => (
            <button
              key={o || 'all'}
              className={`osoa-opp-pill ${originFilter === o ? 'is-active' : ''}`}
              onClick={() => setOriginFilter(o)}
            >
              {o ? ORIGIN_LABEL[o][lang] : t('Toutes', 'All')}
            </button>
          ))}
        </div>
      </div>

      {loading && <div className="page-loading">{t('Chargement…', 'Loading…')}</div>}
      {error && <div className="page-error">{t('Erreur', 'Error')} : {error}</div>}

      {!loading && !error && items && items.length === 0 && (
        <div className="osoa-opp-empty">
          <p className="osoa-opp-empty-title">
            {t('Aucune opportunité pour ce filtre', 'No opportunity for this filter')}
          </p>
          <p className="osoa-opp-empty-text">
            {t(
              'Un dossier apparaîtra ici dès qu’un dépôt AMI, AO, AOI ou DP sera enregistré.',
              'A dossier will appear here as soon as an AMI, AO, AOI or DP deposit is recorded.'
            )}
          </p>
        </div>
      )}

      {!loading && !error && items && items.length > 0 && (
        <div className="osoa-opp-grid">
          {items.map(opp => (
            <div key={opp.id} className={`osoa-opp-card status-${opp.status.toLowerCase()}`}>
              <div className="osoa-opp-card-top">
                <span className="osoa-opp-code">{opp.code}</span>
                <span className={`osoa-opp-status-badge status-${opp.status.toLowerCase()}`}>
                  {STATUS_LABEL[opp.status]?.[lang] || opp.status}
                </span>
              </div>
              <h2 className="osoa-opp-card-title">{opp.title_fr}</h2>
              <div className="osoa-opp-card-meta">
                <span className="osoa-opp-tag">{ORIGIN_LABEL[opp.origin_type]?.[lang] || opp.origin_type}</span>
                {opp.participation_mode && (
                  <span className="osoa-opp-tag">
                    {PARTICIPATION_LABEL[opp.participation_mode]?.[lang] || opp.participation_mode}
                  </span>
                )}
              </div>
              <div className="osoa-opp-card-date">
                {t('Créée le', 'Created on')} {new Date(opp.created_at).toLocaleDateString(lang === 'fr' ? 'fr-FR' : 'en-US')}
              </div>
            </div>
          ))}
        </div>
      )}

      {disclaimer && (
        <p className="osoa-opp-disclaimer">{disclaimer[lang] || disclaimer.fr}</p>
      )}
    </div>
  )
}
