import { useState } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { submitAccessRequest } from '../api/tickets'
import { useLang } from '../i18n/useLang'
import './Register.css'

const AFFILIATE_TYPES = [
  { value: 'STATE',             label: { en: 'State / Government',         fr: 'Etat / Gouvernement' } },
  { value: 'REGIONAL_ORG',      label: { en: 'Regional Organisation',      fr: 'Organisation regionale' } },
  { value: 'ACADEMIC',          label: { en: 'Academic Institution',       fr: 'Institution academique' } },
  { value: 'PRIVATE',           label: { en: 'Private Sector',             fr: 'Secteur prive' } },
  { value: 'INTERNATIONAL_ORG', label: { en: 'International Organisation', fr: 'Organisation internationale' } },
  { value: 'DEVELOPMENT_BANK',  label: { en: 'Development Bank',           fr: 'Banque de developpement' } },
]

export default function Register() {
  const [searchParams] = useSearchParams()
  const { t, lang } = useLang()

  const [form, setForm] = useState({
    org_name:       '',
    affiliate_type: '',
    country:        '',
    contact_name:   '',
    email:          '',
    project_id:     searchParams.get('project') || '',
    country_ref:    searchParams.get('country') || '',
    pillar_ref:     searchParams.get('pillar')  || '',
    message:        '',
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
      await submitAccessRequest({
        org_name:       form.org_name,
        affiliate_type: form.affiliate_type,
        country:        form.country,
        contact_name:   form.contact_name,
        email:          form.email,
        message:        form.message,
        context: {
          project_id:  form.project_id  || null,
          country_ref: form.country_ref || null,
          pillar_ref:  form.pillar_ref  || null,
        }
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
          <h1>Request submitted</h1>
          <p>Thank you. Your affiliation request has been received. We will contact you at <strong>{form.email}</strong>.</p>
          <Link to="/" className="btn-home">{t('register.back_home')}</Link>
        </div>
      </div>
    )
  }

  return (
    <div className="register-page">
      <div className="register-header">
        <h1 className="register-title">{t('register.title')}</h1>
        <p className="register-subtitle">OSA Observatory — Affiliation request</p>
        {(form.country_ref || form.pillar_ref) && (
          <div className="register-context">
            Context :
            {form.country_ref && <span className="ctx-tag">{form.country_ref}</span>}
            {form.pillar_ref  && <span className="ctx-tag">{form.pillar_ref}</span>}
            {form.project_id  && <span className="ctx-tag">Project #{form.project_id}</span>}
          </div>
        )}
      </div>

      <form className="register-form" onSubmit={handleSubmit}>
        <div className="form-row">
          <label>{t('register.type')} *
            <select name="affiliate_type" value={form.affiliate_type}
              onChange={handleChange} required>
              <option value="">— Select —</option>
              {AFFILIATE_TYPES.map(a => (
                <option key={a.value} value={a.value}>{a.label[lang]}</option>
              ))}
            </select>
          </label>
          <label>{t('register.org')} *
            <input name="org_name" value={form.org_name}
              onChange={handleChange} required placeholder="Organisation name" />
          </label>
        </div>

        <div className="form-row">
          <label>{t('register.contact')} *
            <input name="contact_name" value={form.contact_name}
              onChange={handleChange} required placeholder="Full name" />
          </label>
          <label>{t('register.email')} *
            <input name="email" type="email" value={form.email}
              onChange={handleChange} required placeholder="name@organisation.org" />
          </label>
        </div>

        <div className="form-row">
          <label>{t('register.country')}
            <input name="country" value={form.country}
              onChange={handleChange} placeholder="Country of the organisation" />
          </label>
        </div>

        <label className="form-full">{t('register.message')}
          <textarea name="message" value={form.message}
            onChange={handleChange} rows={4}
            placeholder="Describe your interest and intended use..." />
        </label>

        {status === 'error' && (
          <div className="form-error">Submission failed. Please try again or contact us.</div>
        )}

        <div className="form-actions">
          <button type="submit" className="btn-submit" disabled={submitting}>
            {submitting ? t('register.submitting') : t('register.submit')}
          </button>
        </div>
      </form>
    </div>
  )
}
