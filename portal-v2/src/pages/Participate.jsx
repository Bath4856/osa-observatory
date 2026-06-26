import { Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Participate.css'

export default function Participate() {
  const { lang } = useLang()

  return (
    <div className="participate-page">
      <h1 className="participate-title">
        {lang === 'fr' ? 'E-Participation' : 'E-Participation'}
      </h1>

      <div className="participate-gate">
        <div className="gate-icon">🔐</div>
        <h2 className="gate-title">
          {lang === 'fr'
            ? 'Fonctionnalité réservée aux affiliés'
            : 'Feature reserved for affiliates'}
        </h2>
        <p className="gate-text">
          {lang === 'fr'
            ? "La E-Participation est réservée aux affiliés de l'Observatoire Africain de la Souveraineté. Les contributions — signaux de données, propositions de sources, contributions méthodologiques — doivent être attribuables à une organisation identifiée et vérifiée."
            : "E-Participation is reserved for affiliates of the African Sovereignty Observatory. Contributions — data signals, source proposals, methodological contributions — must be attributable to an identified and verified organization."}
        </p>
        <p className="gate-subtext">
          {lang === 'fr'
            ? "Vous souhaitez contribuer à la qualité des données souveraines africaines ?"
            : "Would you like to contribute to the quality of African sovereign data?"}
        </p>
        <Link to="/register" className="gate-btn">
          {lang === 'fr' ? 'Demander une affiliation →' : 'Request affiliation →'}
        </Link>
      </div>
    </div>
  )
}
