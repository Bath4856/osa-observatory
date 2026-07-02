import { Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './About.css'

export default function About() {
  const { t, lang } = useLang()
  const currentYear = new Date().getFullYear()
  const yearsObserved = currentYear - 2010

  const hero = t('about.hero')
  const mission = t('about.mission')
  const why = t('about.why')
  const diagram = t('about.diagram')
  const programs = t('about.programs')
  const pillars = t('about.pillars')
  const approach = t('about.approach')
  const principles = t('about.principles')
  const governance = t('about.governance')
  const closing = t('about.closing')

  const isaProgram = programs.find(p => p.id === 'isa')
  const branchPrograms = programs.filter(p => p.id !== 'isa')

  return (
    <main className="about-page">

      {/* Hero */}
      <section className="about-hero">
        <h1>{hero.title}</h1>
        {hero.paragraphs.map((p, i) => <p key={i}>{p}</p>)}
        <p className="about-hero-stat">
          {lang === 'fr'
            ? `Mesurant les trajectoires de 54 États à travers 10 piliers comportementaux, observées depuis 2010 (${yearsObserved} ans de données).`
            : `Measuring the trajectories of 54 states across 10 behavioural pillars, observed from 2010 (${yearsObserved} years of data).`
          }
        </p>
      </section>

      {/* Mission */}
      <section className="about-section">
        <h2>{mission.title}</h2>
        {mission.paragraphs.map((p, i) => <p key={i}>{p}</p>)}
      </section>

      {/* Why measure */}
      <section className="about-section">
        <h2>{why.title}</h2>
        {why.paragraphs.map((p, i) => <p key={i}>{p}</p>)}
      </section>

      {/* Scientific programmes -- hierarchy diagram */}
      <section className="about-section">
        <h2>{lang === 'fr' ? 'Les programmes scientifiques' : 'The Scientific Programmes'}</h2>

        <div className="osa-diagram" role="img" aria-label="OSA Observatory > ISA > POA / AMAR / GENECO">
          <div className="diagram-node diagram-node--root">
            <span className="diagram-node-title">{diagram.osaTitle}</span>
            <span className="diagram-node-subtitle">{diagram.osaSubtitle}</span>
          </div>

          <div className="diagram-connector" aria-hidden="true" />

          <div className="diagram-node diagram-node--isa">
            <span className="diagram-node-code">{isaProgram.code}</span>
            <span className="diagram-node-subtitle">{isaProgram.subtitle}</span>
          </div>

          <div className="diagram-caption">{diagram.pipelineLabel}</div>

          <div className="diagram-connector" aria-hidden="true" />

          <div className="diagram-node diagram-node--strategic">
            <span className="diagram-node-subtitle">{diagram.strategicLabel}</span>
          </div>

          <div className="diagram-branches">
            {branchPrograms.map(program => (
              <div className="diagram-branch" key={program.id}>
                <div className={`diagram-node diagram-node--branch diagram-node--${program.id}`}>
                  <span className="diagram-node-code">{program.code}</span>
                  <span className="diagram-node-subtitle">{program.subtitle}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Detailed programme cards */}
        <div className="program-grid">
          {programs.map(program => (
            <article className={`program-card program-card--${program.id}`} key={program.id}>
              <h3>{program.code}</h3>
              <h4>{program.subtitle}</h4>
              <p>{program.body}</p>
            </article>
          ))}
        </div>
      </section>

      {/* Pillars */}
      <section className="about-section">
        <h2>{pillars.title}</h2>
        <p>{pillars.intro}</p>
        <div className="pillar-grid">
          {pillars.items.map(item => (
            <span key={item.code} className="pillar-badge">{item.code} — {item.label}</span>
          ))}
        </div>
        <Link className="about-link" to={pillars.linkHref}>
          {pillars.linkLabel} →
        </Link>
      </section>

      {/* Scientific approach */}
      <section className="about-section">
        <h2>{approach.title}</h2>
        {approach.paragraphs.map((p, i) => <p key={i}>{p}</p>)}
        <Link className="about-link" to={approach.linkHref}>
          {approach.linkLabel} →
        </Link>
      </section>

      {/* Core principles */}
      <section className="about-section">
        <h2>{principles.title}</h2>
        <ul className="principles-list">
          {principles.items.map((item, i) => <li key={i}>{item}</li>)}
        </ul>
      </section>

      {/* Scientific governance */}
      <section className="about-section">
        <h2>{governance.title}</h2>
        <p>{governance.body}</p>
      </section>

      {/* Closing */}
      <section className="about-section about-closing">
        <h2>{closing.title}</h2>
        <p>{closing.body}</p>
      </section>

    </main>
  )
}
