import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getCountryScores } from '../api/scores'
import ScoreTable from '../components/ScoreTable/ScoreTable'
import { useLang } from '../i18n/useLang'

export default function Country() {
  const { iso3 } = useParams()
  const { t } = useLang()
  const [scores, setScores] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    getCountryScores(iso3)
      .then(data => {
        const arr = Array.isArray(data) ? data : data.scores || data.results || []
        setScores(arr)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">Loading {iso3}...</div>
  if (error) return <div className="page-error">Error: {error}</div>

  return (
    <div className="country-page">
      <div className="country-header">
        <h1 className="country-title">{iso3}</h1>
        <Link to="/countries" className="back-link">← {t('nav.countries')}</Link>
      </div>
      <ScoreTable iso3={iso3} scoresData={scores} />
      <div className="country-actions">
        <Link to={`/country/${iso3}/projects`} className="btn-projects">
          {t('table.projects')} →
        </Link>
      </div>
    </div>
  )
}
