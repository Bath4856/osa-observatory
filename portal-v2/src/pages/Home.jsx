import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import CountryMap from '../components/CountryMap/CountryMap'
import { getAllScores } from '../api/scores'
import { useLang } from '../i18n/useLang'
import './Home.css'

export default function Home() {
  const { t } = useLang()
  const navigate = useNavigate()
  const [scores, setScores] = useState(null)

  useEffect(() => {
    getAllScores(2024).then(data => {
      const arr = Array.isArray(data) ? data : data.scores || data.results || []
      setScores(arr)
    }).catch(() => setScores([]))
  }, [])

  return (
    <div className="home-page">
      <div className="home-hero">
        <h1 className="hero-title">{t('home.tagline')}</h1>
        <p className="hero-subtitle">{t('home.subtitle')}</p>
      </div>
      <div className="home-body">
        <div className="home-map">
          <CountryMap scoresData={scores} />
        </div>
        <div className="home-intro">
          <p>{t('home.intro')}</p>
          <button className="btn-explore"
            onClick={() => navigate('/countries')}>
            {t('home.explore')}
          </button>
        </div>
      </div>
    </div>
  )
}
