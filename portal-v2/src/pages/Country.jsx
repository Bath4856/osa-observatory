import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getCountryScores, getCountryPillarScores, getCountryHistory } from '../api/scores'
import { getAmarBadges, getConflictBadges } from '../api/alerts'
import { getStructuralObs } from '../api/structural'
import { getCountryIdentity } from '../api/countries'
import ScoreTable from '../components/ScoreTable/ScoreTable'
import { useLang } from '../i18n/useLang'
import './Country.css'

export default function Country() {
  const { iso3 } = useParams()
  const { t, lang } = useLang()
  const [scores, setScores] = useState(null)
  const [pillarScores, setPillarScores] = useState(null)
  const [history, setHistory] = useState(null)
  const [amarHistory, setAmarHistory] = useState(null)
  const [conflictHistory, setConflictHistory] = useState(null)
  const [iosaData, setIosaData] = useState(null)
  const [identity, setIdentity] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

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

  const countryName = identity
    ? (lang === 'fr' ? identity.name_fr : identity.name_en)
    : iso3

  const regionLabel = identity
    ? (lang === 'fr' ? identity.region_fr : identity.region_en)
    : null

  return (
    <div className="country-page">
      <div className="country-header">
        <div className="country-header-text">
          <h1 className="country-title">{countryName}</h1>
          {regionLabel && (
            <span className="country-region">{regionLabel} · {iso3}</span>
          )}
        </div>
        <Link to="/countries" className="back-link">← {t('nav.countries')}</Link>
      </div>
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
  )
}
