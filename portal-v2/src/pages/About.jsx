import { useLang } from '../i18n/useLang'
import aboutContent from '../content/about_content.json'
import './About.css'

export default function About() {
  const { lang } = useLang()

  return (
    <div className="about-page">
      <h1 className="about-title">About OSA Observatory</h1>
      <p className="about-intro">
        The OSA Observatory (Observatoire de la Souverainete Africaine) is an independent
        scientific infrastructure measuring African sovereignty across 54 countries,
        10 pillars, and 15 years of observed data (2010–2024).
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
