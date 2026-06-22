import { useLang } from '../i18n/useLang'
import aboutContent from '../content/about_content.json'
import './About.css'

export default function About() {
  const { lang } = useLang()
  const currentYear = new Date().getFullYear()
  const yearsObserved = currentYear - 2010

  return (
    <div className="about-page">
      <h1 className="about-title">About OSA Observatory</h1>
      <p className="about-intro">
        {lang === 'fr'
          ? `OSA Observatory (Observatoire de la Souveraineté Africaine) est une infrastructure africaine d'observation souveraine — mesurant les trajectoires de 54 États à travers 10 piliers comportementaux, observées depuis 2010 (${yearsObserved} ans de données).`
          : `The OSA Observatory (Observatoire de la Souveraineté Africaine) is an African infrastructure for sovereign observation — measuring the trajectories of 54 states across 10 behavioural pillars, observed from 2010 (${yearsObserved} years of data).`
        }
      </p>
      <div className="about-blocks">
        {aboutContent.blocks.map(block => (
          <section key={block.id} id={block.anchor} className="about-block">
            <h2 className="block-title">{block.title[lang]}</h2>
            <p className="block-body">{block.body[lang]}</p>
          </section>
        ))}
      </div>
    </div>
  )
}