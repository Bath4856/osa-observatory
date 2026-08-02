import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import { getVisions, getVisionDeliverables } from '../api/oim'
import './VisionDetail.css'

const STATUS_LABEL = {
  DRAFT:     { fr: 'Brouillon', en: 'Draft' },
  VALIDATED: { fr: 'Validée',   en: 'Validated' },
  ARCHIVED:  { fr: 'Archivée',  en: 'Archived' },
}

export default function VisionDetail() {
  const { iso3, pillarCode } = useParams()
  const { lang } = useLang()
  const [vision, setVision] = useState(null)
  const [deliverables, setDeliverables] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    getVisions({ country_iso3: iso3, pillar_code: pillarCode })
      .then(async (d) => {
        const latest = d.items?.[0] || null
        setVision(latest)
        if (latest) {
          const del = await getVisionDeliverables(latest.id)
          setDeliverables(del.items || [])
        } else {
          setDeliverables([])
        }
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3, pillarCode])

  const t = (fr, en) => (lang === 'fr' ? fr : en)

  if (loading) return <div className="page-loading">{t('Chargement…', 'Loading…')}</div>
  if (error)   return <div className="page-error">{t('Erreur', 'Error')} : {error}</div>

  const etudeOpportunite = deliverables?.find(d => d.deliverable_type === 'ETUDE_OPPORTUNITE')
  const hasValidatedSummary = etudeOpportunite?.summary_status === 'HUMAN_VALIDATED'

  return (
    <div className="vision-detail-page">
      <div className="vision-detail-header">
        <span className="vision-detail-eyebrow">{t('MOTEUR DE GÉNIE SCIENTIFIQUE', 'SCIENTIFIC ENGINEERING ENGINE')}</span>
        <h1 className="vision-detail-title">
          {t('Vision stratégique', 'Strategic vision')} — {pillarCode} · {iso3}
        </h1>
        <Link to={`/pillar/${pillarCode}?country=${iso3}`} className="back-link">
          ← {t('Retour au pilier', 'Back to pillar')}
        </Link>
      </div>

      {!vision && (
        <div className="vision-detail-empty">
          <p className="vision-detail-empty-title">
            {t('Aucune vision disponible pour ce pays et ce pilier', 'No vision available for this country and pillar')}
          </p>
          <p className="vision-detail-empty-text">
            {t(
              'Une vision stratégique est produite chaque année par le Moteur de génie scientifique, à partir des données ISA et POA validées.',
              'A strategic vision is produced each year by the Scientific Engineering Engine, based on validated ISA and POA data.'
            )}
          </p>
        </div>
      )}

      {vision && (
        <>
          <div className="vision-detail-meta">
            <span className="vision-detail-year">{vision.year}</span>
            <span className={`vision-detail-status status-${vision.status.toLowerCase()}`}>
              {STATUS_LABEL[vision.status]?.[lang] || vision.status}
            </span>
          </div>

          <section className="vision-detail-section">
            <h2>{t("Étude d'opportunité", 'Opportunity study')}</h2>
            {hasValidatedSummary ? (
              <p className="vision-detail-summary">
                {lang === 'fr' ? etudeOpportunite.public_summary_fr : etudeOpportunite.public_summary_en}
              </p>
            ) : (
              <p className="vision-detail-pending">
                {t(
                  "Cette étude est en cours de rédaction et n'a pas encore été validée pour publication.",
                  'This study is currently being drafted and has not yet been validated for publication.'
                )}
              </p>
            )}
          </section>

          <section className="vision-detail-section vision-detail-premium">
            <h2>{t('Approfondir', 'Go deeper')}</h2>
            <div className="vision-detail-premium-grid">
              <div className="vision-detail-premium-card">
                <h3>{t('Schéma directeur', 'Master plan')}</h3>
                <p>{t('Architecture cible et gouvernance détaillées.', 'Detailed target architecture and governance.')}</p>
                <span className="vision-detail-premium-tag">
                  {t('Disponible sur demande institutionnelle', 'Available on institutional request')}
                </span>
              </div>
              <div className="vision-detail-premium-card">
                <h3>{t("Plan d'actions", 'Action plan')}</h3>
                <p>{t('Actions concrètes et projets dérivés.', 'Concrete actions and derived projects.')}</p>
                <span className="vision-detail-premium-tag">
                  {t('Disponible sur demande institutionnelle', 'Available on institutional request')}
                </span>
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  )
}
