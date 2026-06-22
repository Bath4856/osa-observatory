import { useState } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { submitAccessRequest } from '../api/tickets'
import { useLang } from '../i18n/useLang'
import './Participate.css'

const CONTRIBUTION_TYPES = [
  {
    value: 'DATA_SIGNAL',
    label: { en: 'Data signal', fr: 'Signal de données' },
    desc: { en: 'Report an anomaly, incorrect value, or suggest an alternative primary source for a specific indicator.', fr: 'Signalez une anomalie, une valeur incorrecte, ou proposez une source primaire alternative pour un indicateur.' },
    fields: ['country', 'indicator', 'year', 'message']
  },
  {
    value: 'SOURCE_PROPOSAL',
    label: { en: 'Source proposal', fr: 'Proposition de source' },
    desc: { en: 'Suggest a new primary data source that could improve coverage of a sovereign pillar.', fr: 'Proposez une nouvelle source de données primaires pour améliorer la couverture d\'un pilier souverain.' },
    fields: ['pillar', 'source_url', 'message']
  },
  {
    value: 'METHODOLOGICAL',
    label: { en: 'Methodological contribution', fr: 'Contribution méthodologique' },
    desc: { en: 'Propose a new indicator, a methodological improvement, or a doctrinal comment for Scientific Committee review.', fr: 'Proposez un nouvel indicateur, une amélioration méthodologique, ou un commentaire doctrinal pour le Comité Scientifique.' },
    fields: ['pillar', 'message']
  }
]

export default function Participate() {
  const [searchParams] = useSearchParams()
  const { lang } = useLang()
  const [type, setType] = useState('')
  const [form, setForm] = useState({
    name: '', email: '',
    country: searchParams.get('country') || '',
    indicator: '', year: '', pillar: '', source_url: '', message: ''
  })
  const [status, setStatus] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  const selectedType = CONTRIBUTION_TYPES.find(t => t.value === type)

  const handleChange = e => setForm(f => ({ ...f, [e.target.name]: e.target.value }))

  const handleSubmit = async e => {
    e.preventDefault()
    setSubmitting(true)
    try {
      await submitAccessRequest({ ...form, contribution_type: type, ticket_type: 'SIGNALEMENT' })
      setStatus('success')
    } catch {
      setStatus('error')
    } finally {
      setSubmitting(false)
    }
  }

  if (status === 'success') return (
    <div className="participate-page">
      <div className="participate-success">
        <h1>{lang === 'fr' ? 'Contribution enregistrée' : 'Contribution recorded'}</h1>
        <p>{lang === 'fr' ? 'Merci. Votre contribution a été transmise au Comité Scientifique OSA.' : 'Thank you. Your contribution has been transmitted to the OSA Scientific Committee.'}</p>
        <Link to="/" className="btn-home">← {lang === 'fr' ? 'Accueil' : 'Home'}</Link>
      </div>
    </div>
  )

  return (
    <div className="participate-page">
      <h1 className="participate-title">
        {lang === 'fr' ? 'E-Participation' : 'E-Participation'}
      </h1>
      <p className="participate-intro">
        {lang === 'fr'
          ? 'Contribuez à la qualité des données souveraines africaines. Signalez une anomalie, proposez une source primaire, ou soumettez une contribution méthodologique au Comité Scientifique.'
          : 'Contribute to the quality of African sovereign data. Report an anomaly, propose a primary source, or submit a methodological contribution to the Scientific Committee.'}
      </p>

      <div className="type-selector">
        {CONTRIBUTION_TYPES.map(ct => (
          <button key={ct.value}
            className={`type-btn ${type === ct.value ? 'active' : ''}`}
            onClick={() => setType(ct.value)}>
            <strong>{ct.label[lang]}</strong>
            <span>{ct.desc[lang]}</span>
          </button>
        ))}
      </div>

      {type && (
        <form className="participate-form" onSubmit={handleSubmit}>
          <div className="form-row">
            <label>{lang === 'fr' ? 'Nom' : 'Name'} *
              <input name="name" value={form.name} onChange={handleChange} required />
            </label>
            <label>Email *
              <input name="email" type="email" value={form.email} onChange={handleChange} required />
            </label>
          </div>

          {selectedType?.fields.includes('country') && (
            <label>{lang === 'fr' ? 'Pays (ISO3)' : 'Country (ISO3)'}
              <input name="country" value={form.country} onChange={handleChange} placeholder="e.g. DZA" />
            </label>
          )}
          {selectedType?.fields.includes('indicator') && (
            <label>{lang === 'fr' ? 'Indicateur' : 'Indicator'}
              <input name="indicator" value={form.indicator} onChange={handleChange} placeholder="e.g. ECO_GDP" />
            </label>
          )}
          {selectedType?.fields.includes('year') && (
            <label>{lang === 'fr' ? 'Année' : 'Year'}
              <input name="year" value={form.year} onChange={handleChange} placeholder="e.g. 2022" />
            </label>
          )}
          {selectedType?.fields.includes('pillar') && (
            <label>{lang === 'fr' ? 'Pilier' : 'Pillar'}
              <input name="pillar" value={form.pillar} onChange={handleChange} placeholder="e.g. PECO" />
            </label>
          )}
          {selectedType?.fields.includes('source_url') && (
            <label>{lang === 'fr' ? 'URL de la source' : 'Source URL'}
              <input name="source_url" value={form.source_url} onChange={handleChange} placeholder="https://..." />
            </label>
          )}

          <label>{lang === 'fr' ? 'Message *' : 'Message *'}
            <textarea name="message" value={form.message} onChange={handleChange} rows={5} required
              placeholder={lang === 'fr' ? 'Décrivez votre contribution...' : 'Describe your contribution...'} />
          </label>

          {status === 'error' && <div className="form-error">Submission failed. Please try again.</div>}

          <button type="submit" className="btn-submit" disabled={submitting}>
            {submitting ? '...' : (lang === 'fr' ? 'Soumettre' : 'Submit contribution →')}
          </button>
        </form>
      )}
    </div>
  )
}