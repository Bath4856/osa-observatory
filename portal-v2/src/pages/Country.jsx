import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getCountryScores, getCountryPillarScores } from '../api/scores'
import ScoreTable from '../components/ScoreTable/ScoreTable'
import { useLang } from '../i18n/useLang'
import './Country.css'

export default function Country() {
  const { iso3 } = useParams()
  const { t } = useLang()
  const [scores, setScores] = useState(null)
  const [pillarScores, setPillarScores] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    Promise.all([
      getCountryScores(iso3),
      getCountryPillarScores(iso3)
    ])
      .then(([isa, pillars]) => {
        setScores(isa)
        setPillarScores(pillars)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (error) return <div className="page-error">Error: {error}</div>

  return (
    <div className="country-page">
      <div className="country-header">
        <h1 className="country-title">{iso3}</h1>
        <Link to="/countries" className="back-link">← {t('nav.countries')}</Link>
      </div>
      <ScoreTable iso3={iso3} scoresData={scores} pillarData={pillarScores} />
      <div className="country-actions">
        <Link to={`/country/${iso3}/projects`} className="btn-projects">
          {t('table.projects')} →
        </Link>
      </div>
    </div>
  )
}
