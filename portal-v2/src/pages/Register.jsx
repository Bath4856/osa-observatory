import { useState } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { submitAffiliationRequest } from '../api/tickets'
import { useLang } from '../i18n/useLang'
import './Register.css'

const AFFILIATE_TYPES = [
  { value: 'STATE',             label: { en: 'State / Government',         fr: 'État / Gouvernement' } },
  { value: 'REGIONAL_ORG',      label: { en: 'Regional Organisation',      fr: 'Organisation régionale' } },
  { value: 'ACADEMIC',          label: { en: 'Academic Institution',       fr: 'Institution académique' } },
  { value: 'PRIVATE',           label: { en: 'Private Sector',             fr: 'Secteur privé' } },
  { value: 'INTERNATIONAL_ORG', label: { en: 'International Organisation', fr: 'Organisation internationale' } },
  { value: 'DEVELOPMENT_BANK',  label: { en: 'Development Bank',           fr: 'Banque de développement' } },
]

export default function Register() {
  const [searchParams] = useSearchParams()
  const { t, lang } = useLang()

  const [form, setForm] = useState({
    last_name:      '',
    first_name:     '',
    org_name:       '',
    affiliate_type: '',
    function_title: '',
    country:        '',
    email:          '',
    motivation:     '',
    project_id:     searchParams.get('project') || '',
    country_ref:    searchParams.get('country') || '',
    pillar_ref:     searchParams.get('pillar')  || '',
  })

  const [status, setStatus] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  const handleChange = (e) => {
    setForm(f => ({ ...f, [e.target.name]: e.target.value }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSubmitting(true)
    try {
      await submitAffiliationRequest({
        last_name:      form.last_name,
        first_name:     form.first_name,
        function_title: form.function_title || null,
        email:          form.email,
        org_name:       form.org_name,
        affiliate_type: form.affiliate_type,
        country:        form.country || null,
        motivation:     form.motivation || null,
      })
      setStatus('success')
    } catch {
      setStatus('error')
    } finally {
      setSubmitting(false)
    }
  }

  if (status === 'success') {
    return (
      <div className="register-page">
        <div className="register-success">
          <h1>{lang === 'fr' ? 'Demande soumise' : 'Request submitted'}</h1>
          <p>
            {lang === 'fr'
              ? `Merci. Votre demande d'affiliation a été reçue. Nous vous contacterons à l'adresse `
              : `Thank you. Your affiliation request has been received. We will contact you at `}
            <strong>{form.email}</strong>.
          </p>
          <Link to="/" className="btn-home">← {lang === 'fr' ? 'Accueil' : 'Home'}</Link>
        </div>
      </div>
    )
  }

  return (
    <div className="register-page">
      <div className="register-header">
        <h1 className="register-title">
          {lang === 'fr' ? 'Demande d\'affiliation' : 'Affiliation request'}
        </h1>
        <p className="register-subtitle">
          {lang === 'fr'
            ? 'OSA Observatory — Observatoire de la Souveraineté Africaine'
            : 'OSA Observatory — African Sovereignty Observatory'}
        </p>
        {(form.country_ref || form.pillar_ref) && (
          <div className="register-context">
            {form.country_ref && <span className="ctx-tag">{form.country_ref}</span>}
            {form.pillar_ref  && <span className="ctx-tag">{form.pillar_ref}</span>}
            {form.project_id  && <span className="ctx-tag">Projet #{form.project_id}</span>}
          </div>
        )}
      </div>

      <form className="register-form" onSubmit={handleSubmit}>

        {/* Identité */}
        <div className="form-section-title">
          {lang === 'fr' ? 'Identité' : 'Identity'}
        </div>
        <div className="form-row">
          <label>{lang === 'fr' ? 'Nom *' : 'Last name *'}
            <input name="last_name" value={form.last_name}
              onChange={handleChange} required
              placeholder={lang === 'fr' ? 'Nom de famille' : 'Last name'} />
          </label>
          <label>{lang === 'fr' ? 'Prénom *' : 'First name *'}
            <input name="first_name" value={form.first_name}
              onChange={handleChange} required
              placeholder={lang === 'fr' ? 'Prénom' : 'First name'} />
          </label>
        </div>
        <div className="form-row">
          <label>{lang === 'fr' ? 'Fonction' : 'Function / Title'}
            <input name="function_title" value={form.function_title}
              onChange={handleChange}
              placeholder={lang === 'fr' ? 'Ex : Directeur de recherche' : 'Ex: Research Director'} />
          </label>
          <label>{lang === 'fr' ? 'Email institutionnel *' : 'Institutional email *'}
            <input name="email" type="email" value={form.email}
              onChange={handleChange} required
              placeholder="nom@organisation.org" />
          </label>
        </div>

        {/* Organisation */}
        <div className="form-section-title">
          {lang === 'fr' ? 'Organisation' : 'Organisation'}
        </div>
        <div className="form-row">
          <label>{lang === 'fr' ? 'Type d\'organisation *' : 'Organisation type *'}
            <select name="affiliate_type" value={form.affiliate_type}
              onChange={handleChange} required>
              <option value="">{lang === 'fr' ? '— Sélectionner —' : '— Select —'}</option>
              {AFFILIATE_TYPES.map(a => (
                <option key={a.value} value={a.value}>{a.label[lang]}</option>
              ))}
            </select>
          </label>
          <label>{lang === 'fr' ? 'Nom de l\'organisation *' : 'Organisation name *'}
            <input name="org_name" value={form.org_name}
              onChange={handleChange} required
              placeholder={lang === 'fr' ? 'Nom complet de l\'organisation' : 'Full organisation name'} />
          </label>
        </div>
        <div className="form-row">
          <label>{lang === 'fr' ? 'Pays *' : 'Country *'}
            <input name="country" value={form.country}
              onChange={handleChange} required
              placeholder={lang === 'fr' ? 'Pays du siège de l\'organisation' : 'Country of organisation headquarters'} />
          </label>
        </div>

        {/* Motivation */}
        <div className="form-section-title">
          {lang === 'fr' ? 'Motivation' : 'Motivation'}
        </div>
        <label className="form-full">
          {lang === 'fr'
            ? 'Décrivez votre intérêt pour l\'OSA et l\'usage envisagé *'
            : 'Describe your interest in the OSA and intended use *'}
          <textarea name="motivation" value={form.motivation}
            onChange={handleChange} rows={5} required
            placeholder={lang === 'fr'
              ? 'Contexte de votre organisation, objectifs de la demande d\'affiliation, usage prévu des données...'
              : 'Your organisation context, objectives of the affiliation request, intended use of data...'} />
        </label>

        {status === 'error' && (
          <div className="form-error">
            {lang === 'fr'
              ? 'Envoi échoué. Veuillez réessayer.'
              : 'Submission failed. Please try again.'}
          </div>
        )}

        <div className="form-actions">
          <button type="submit" className="btn-submit" disabled={submitting}>
            {submitting
              ? (lang === 'fr' ? 'Envoi en cours...' : 'Submitting...')
              : (lang === 'fr' ? 'Envoyer la demande →' : 'Submit request →')}
          </button>
        </div>
      </form>
    </div>
  )
}
