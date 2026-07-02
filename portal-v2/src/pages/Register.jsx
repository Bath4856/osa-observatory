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

const AFRICAN_COUNTRIES = [
  { iso3: 'DZA', fr: 'Algérie',                  en: 'Algeria' },
  { iso3: 'AGO', fr: 'Angola',                    en: 'Angola' },
  { iso3: 'BEN', fr: 'Bénin',                     en: 'Benin' },
  { iso3: 'BWA', fr: 'Botswana',                  en: 'Botswana' },
  { iso3: 'BFA', fr: 'Burkina Faso',              en: 'Burkina Faso' },
  { iso3: 'BDI', fr: 'Burundi',                   en: 'Burundi' },
  { iso3: 'CPV', fr: 'Cabo Verde',                en: 'Cabo Verde' },
  { iso3: 'CMR', fr: 'Cameroun',                  en: 'Cameroon' },
  { iso3: 'CAF', fr: 'République centrafricaine', en: 'Central African Republic' },
  { iso3: 'TCD', fr: 'Tchad',                     en: 'Chad' },
  { iso3: 'COM', fr: 'Comores',                   en: 'Comoros' },
  { iso3: 'COD', fr: 'Rép. dém. du Congo',        en: 'Dem. Rep. Congo' },
  { iso3: 'COG', fr: 'Congo',                     en: 'Congo' },
  { iso3: 'CIV', fr: "Côte d'Ivoire",             en: "Côte d'Ivoire" },
  { iso3: 'DJI', fr: 'Djibouti',                  en: 'Djibouti' },
  { iso3: 'EGY', fr: 'Égypte',                    en: 'Egypt' },
  { iso3: 'GNQ', fr: 'Guinée équatoriale',        en: 'Equatorial Guinea' },
  { iso3: 'ERI', fr: 'Érythrée',                  en: 'Eritrea' },
  { iso3: 'SWZ', fr: 'Eswatini',                  en: 'Eswatini' },
  { iso3: 'ETH', fr: 'Éthiopie',                  en: 'Ethiopia' },
  { iso3: 'GAB', fr: 'Gabon',                     en: 'Gabon' },
  { iso3: 'GMB', fr: 'Gambie',                    en: 'Gambia' },
  { iso3: 'GHA', fr: 'Ghana',                     en: 'Ghana' },
  { iso3: 'GIN', fr: 'Guinée',                    en: 'Guinea' },
  { iso3: 'GNB', fr: 'Guinée-Bissau',             en: 'Guinea-Bissau' },
  { iso3: 'KEN', fr: 'Kenya',                     en: 'Kenya' },
  { iso3: 'LSO', fr: 'Lesotho',                   en: 'Lesotho' },
  { iso3: 'LBR', fr: 'Libéria',                   en: 'Liberia' },
  { iso3: 'LBY', fr: 'Libye',                     en: 'Libya' },
  { iso3: 'MDG', fr: 'Madagascar',                en: 'Madagascar' },
  { iso3: 'MWI', fr: 'Malawi',                    en: 'Malawi' },
  { iso3: 'MLI', fr: 'Mali',                      en: 'Mali' },
  { iso3: 'MRT', fr: 'Mauritanie',                en: 'Mauritania' },
  { iso3: 'MUS', fr: 'Maurice',                   en: 'Mauritius' },
  { iso3: 'MAR', fr: 'Maroc',                     en: 'Morocco' },
  { iso3: 'MOZ', fr: 'Mozambique',                en: 'Mozambique' },
  { iso3: 'NAM', fr: 'Namibie',                   en: 'Namibia' },
  { iso3: 'NER', fr: 'Niger',                     en: 'Niger' },
  { iso3: 'NGA', fr: 'Nigéria',                   en: 'Nigeria' },
  { iso3: 'RWA', fr: 'Rwanda',                    en: 'Rwanda' },
  { iso3: 'STP', fr: 'Sao Tomé-et-Principe',      en: 'Sao Tome and Principe' },
  { iso3: 'SEN', fr: 'Sénégal',                   en: 'Senegal' },
  { iso3: 'SYC', fr: 'Seychelles',                en: 'Seychelles' },
  { iso3: 'SLE', fr: 'Sierra Leone',              en: 'Sierra Leone' },
  { iso3: 'SOM', fr: 'Somalie',                   en: 'Somalia' },
  { iso3: 'ZAF', fr: 'Afrique du Sud',            en: 'South Africa' },
  { iso3: 'SSD', fr: 'Soudan du Sud',             en: 'South Sudan' },
  { iso3: 'SDN', fr: 'Soudan',                    en: 'Sudan' },
  { iso3: 'TZA', fr: 'Tanzanie',                  en: 'Tanzania' },
  { iso3: 'TGO', fr: 'Togo',                      en: 'Togo' },
  { iso3: 'TUN', fr: 'Tunisie',                   en: 'Tunisia' },
  { iso3: 'UGA', fr: 'Ouganda',                   en: 'Uganda' },
  { iso3: 'ZMB', fr: 'Zambie',                    en: 'Zambia' },
  { iso3: 'ZWE', fr: 'Zimbabwe',                  en: 'Zimbabwe' },
]

const BENEFITS = {
  fr: [
    { icon: '📚', text: 'Participer aux groupes de travail des dix piliers de l\'OSA' },
    { icon: '🧩', text: 'Contribuer aux consultations ouvertes aux affiliés' },
    { icon: '🧪', text: 'Proposer des améliorations méthodologiques' },
    { icon: '📈', text: 'Suivre l\'évolution de vos contributions' },
  ],
  en: [
    { icon: '📚', text: 'Participate in the working groups of the ten OSA pillars' },
    { icon: '🧩', text: 'Contribute to consultations open to affiliates' },
    { icon: '🧪', text: 'Propose methodological improvements' },
    { icon: '📈', text: 'Track the progress of your contributions' },
  ],
}

const JOURNEY = {
  fr: ['Affilié', 'Choisissez vos groupes de travail', 'Participez aux consultations', 'Contribuez aux projets de l\'OSA', 'Vos contributions sont évaluées par les comités compétents'],
  en: ['Affiliated', 'Choose your working groups', 'Participate in consultations', 'Contribute to OSA projects', 'Your contributions are evaluated by the relevant committees'],
}

export default function Register() {
  const [searchParams] = useSearchParams()
  const { lang } = useLang()

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

  const [status, setStatus]         = useState(null)
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
    } catch (err) {
      const msg = err.message || ''
      if (msg.includes('deja en cours') || msg.includes('already pending')) {
        setStatus('pending_email')
      } else if (msg.includes('actif existe') || msg.includes('already exists')) {
        setStatus('already_active')
      } else if (msg.includes('Trop de demandes') || msg.includes('Too many')) {
        setStatus('rate_limit')
      } else {
        setStatus('error')
      }
    } finally {
      setSubmitting(false)
    }
  }

  // ── Ecran de succes ────────────────────────────────────────────────────────
  if (status === 'success') {
    return (
      <div className="register-page">
        <div className="register-success">
          <div className="success-icon">✉</div>
          <h1>{lang === 'fr' ? 'Vérifiez votre boîte mail' : 'Check your inbox'}</h1>
          <p className="success-email"><strong>{form.email}</strong></p>
          <p className="success-main">
            {lang === 'fr'
              ? "Un email de confirmation vient d'être envoyé à cette adresse. Votre affiliation sera activée dès que vous aurez cliqué sur le lien de confirmation."
              : "A confirmation email has just been sent to this address. Your affiliation will be activated as soon as you click the confirmation link."}
          </p>
          <p className="success-sub">
            {lang === 'fr'
              ? "Si vous ne trouvez pas ce message, vérifiez votre dossier courriers indésirables. Le lien est valable 48 heures."
              : "If you cannot find the message, please check your spam folder. The link is valid for 48 hours."}
          </p>
          <p className="success-note">
            {lang === 'fr'
              ? "L'OSA distingue l'affiliation (accès) de la gouvernance scientifique (comités). En tant qu'affilié, vous participez à la production collective des connaissances souveraines africaines."
              : "OSA distinguishes affiliation (access) from scientific governance (committees). As an affiliate, you contribute to the collective production of African sovereign knowledge."}
          </p>
          <div className="success-actions">
            <Link to="/" className="btn-home">← {lang === 'fr' ? 'Accueil' : 'Home'}</Link>
            <Link to="/register" className="btn-resend">
              {lang === 'fr' ? 'Renvoyer un lien →' : 'Resend a link →'}
            </Link>
          </div>
        </div>
      </div>
    )
  }

  // ── Formulaire ─────────────────────────────────────────────────────────────
  return (
    <div className="register-page">
      <div className="register-header">
        <h1 className="register-title">
          {lang === 'fr'
            ? "Devenir affilié à l'Observatoire Africain de la Souveraineté"
            : 'Become an affiliate of the African Sovereignty Observatory'}
        </h1>
        <p className="register-mission">
          {lang === 'fr'
            ? "Rejoignez le réseau des affiliés de l'OSA et contribuez à l'analyse, à la mesure et au renforcement des souverainetés africaines."
            : "Join the OSA affiliate network and contribute to the analysis, measurement and strengthening of African sovereignties."}
        </p>

        {/* Etapes */}
        <div className="register-steps">
          <div className="register-step">
            <span className="step-num">①</span>
            <span className="step-label">{lang === 'fr' ? 'Remplissez le formulaire' : 'Fill in the form'}</span>
          </div>
          <div className="register-step-sep">→</div>
          <div className="register-step">
            <span className="step-num">②</span>
            <span className="step-label">{lang === 'fr' ? 'Confirmez votre email' : 'Confirm your email'}</span>
          </div>
          <div className="register-step-sep">→</div>
          <div className="register-step register-step--active">
            <span className="step-num">③</span>
            <span className="step-label">{lang === 'fr' ? 'Votre affiliation est activée' : 'Your affiliation is activated'}</span>
          </div>
        </div>
        <p className="register-no-validation">
          {lang === 'fr'
            ? "✓ Votre affiliation est activée automatiquement après confirmation de votre adresse électronique."
            : "✓ Your affiliation is automatically activated after confirming your email address."}
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
        <div className="form-section-title">{lang === 'fr' ? 'Identité' : 'Identity'}</div>
        <div className="form-row">
          <label>{lang === 'fr' ? 'Nom *' : 'Last name *'}
            <input name="last_name" value={form.last_name} onChange={handleChange} required
              placeholder={lang === 'fr' ? 'Nom de famille' : 'Last name'} />
          </label>
          <label>{lang === 'fr' ? 'Prénom *' : 'First name *'}
            <input name="first_name" value={form.first_name} onChange={handleChange} required
              placeholder={lang === 'fr' ? 'Prénom' : 'First name'} />
          </label>
        </div>
        <div className="form-row">
          <label>{lang === 'fr' ? 'Fonction' : 'Function / Title'}
            <input name="function_title" value={form.function_title} onChange={handleChange}
              placeholder={lang === 'fr' ? 'Ex : Directeur de recherche' : 'Ex: Research Director'} />
          </label>
          <label>{lang === 'fr' ? 'Email institutionnel *' : 'Institutional email *'}
            <input name="email" type="email" value={form.email} onChange={handleChange} required
              placeholder="nom@organisation.org" />
          </label>
        </div>

        {/* Organisation */}
        <div className="form-section-title">{lang === 'fr' ? 'Organisation' : 'Organisation'}</div>
        <div className="form-row">
          <label>{lang === 'fr' ? "Type d'organisation *" : 'Organisation type *'}
            <select name="affiliate_type" value={form.affiliate_type} onChange={handleChange} required>
              <option value="">{lang === 'fr' ? '— Sélectionner —' : '— Select —'}</option>
              {AFFILIATE_TYPES.map(a => (
                <option key={a.value} value={a.value}>{a.label[lang]}</option>
              ))}
            </select>
          </label>
          <label>{lang === 'fr' ? "Nom de l'organisation *" : 'Organisation name *'}
            <input name="org_name" value={form.org_name} onChange={handleChange} required
              placeholder={lang === 'fr' ? "Nom complet de l'organisation" : 'Full organisation name'} />
          </label>
        </div>
        <div className="form-row">
          <label>{lang === 'fr' ? 'Pays *' : 'Country *'}
            <select name="country" value={form.country} onChange={handleChange} required>
              <option value="">{lang === 'fr' ? '— Sélectionner —' : '— Select —'}</option>
              {AFRICAN_COUNTRIES.map(c => (
                <option key={c.iso3} value={c.iso3}>{c[lang]} ({c.iso3})</option>
              ))}
            </select>
          </label>
        </div>

        {/* Présentation intérêt */}
        <div className="form-section-title">
          {lang === 'fr' ? "Présentation de votre intérêt (optionnelle)" : 'Presentation of your interest (optional)'}
        </div>
        <p className="form-section-hint">
          {lang === 'fr'
            ? "Cette information nous aide à mieux connaître les usages envisagés de la plateforme OSA."
            : "This information helps us better understand the intended uses of the OSA platform."}
        </p>
        <label className="form-full">
          <textarea name="motivation" value={form.motivation} onChange={handleChange} rows={4}
            placeholder={lang === 'fr'
              ? "Contexte de votre organisation, objectifs de la demande d'affiliation, usage prévu des données..."
              : 'Your organisation context, objectives of the affiliation request, intended use of data...'} />
        </label>

        {/* Bénéfices */}
        <div className="register-benefits">
          <p className="benefits-title">
            {lang === 'fr' ? '✓ Après confirmation de votre email, vous pourrez :' : '✓ After confirming your email, you will be able to:'}
          </p>
          <div className="benefits-grid">
            {BENEFITS[lang].map((b, i) => (
              <div key={i} className="benefit-card">
                <span className="benefit-icon">{b.icon}</span>
                <span className="benefit-text">{b.text}</span>
              </div>
            ))}
          </div>

          {/* Parcours affilié */}
          <div className="register-journey">
            <p className="journey-title">{lang === 'fr' ? 'Votre parcours' : 'Your journey'}</p>
            <div className="journey-steps">
              {JOURNEY[lang].map((step, i) => (
                <div key={i} className="journey-step">
                  <span className={`journey-dot${i === 0 ? ' journey-dot--active' : ''}`} />
                  <span className="journey-label">{step}</span>
                  {i < JOURNEY[lang].length - 1 && <span className="journey-arrow">↓</span>}
                </div>
              ))}
            </div>
          </div>

          {/* Note comités */}
          <div className="register-committees-note">
            <p className="committees-note-title">
              {lang === 'fr' ? 'ℹ Information' : 'ℹ Information'}
            </p>
            <p className="committees-note-text">
              {lang === 'fr'
                ? "L'affiliation ne donne pas automatiquement accès aux comités. Les membres des comités (Technique, Scientifique, Éthique) sont proposés par cooptation puis nommés conformément aux règles de gouvernance de l'OSA."
                : "Affiliation does not automatically grant access to committees. Committee members (Technical, Scientific, Ethics) are proposed by cooptation and appointed in accordance with OSA governance rules."}
            </p>
          </div>
        </div>

        {/* Messages d'erreur */}
        {status === 'error' && (
          <div className="form-error">
            {lang === 'fr' ? 'Envoi échoué. Veuillez réessayer.' : 'Submission failed. Please try again.'}
          </div>
        )}
        {status === 'pending_email' && (
          <div className="form-error form-error--info">
            {lang === 'fr'
              ? 'Un email de confirmation vous a déjà été envoyé. Vérifiez votre boîte mail.'
              : 'A confirmation email has already been sent to you. Please check your inbox.'}
          </div>
        )}
        {status === 'already_active' && (
          <div className="form-error form-error--info">
            {lang === 'fr'
              ? 'Un compte actif existe déjà pour cet email.'
              : 'An active account already exists for this email.'}
          </div>
        )}
        {status === 'rate_limit' && (
          <div className="form-error form-error--warning">
            {lang === 'fr'
              ? 'Trop de tentatives. Veuillez patienter avant de réessayer.'
              : 'Too many attempts. Please wait before trying again.'}
          </div>
        )}

        {/* Lien confirmation + renvoi */}
        <div className="register-confirm-links">
          <span className="confirm-links-label">
            {lang === 'fr' ? 'Vous avez déjà reçu un email ?' : 'Already received an email?'}
          </span>
          <Link to="/confirm-email" className="confirm-link">
            {lang === 'fr' ? 'Confirmer mon adresse →' : 'Confirm my address →'}
          </Link>
          <Link to="/register" className="confirm-link" onClick={() => { setStatus(null); setForm(f => ({...f, email:''})) }}>
            {lang === 'fr' ? 'Renvoyer un lien' : 'Resend a link'}
          </Link>
        </div>

        {/* CGU */}
        <p className="register-terms">
          {lang === 'fr'
            ? <>En cliquant sur « Recevoir le lien de confirmation », vous acceptez les <Link to="/terms">conditions d'utilisation</Link> de la plateforme OSA et la politique de protection des données.</>
            : <>By clicking "Receive confirmation link", you agree to the OSA platform <Link to="/terms">terms of use</Link> and data protection policy.</>}
        </p>

        <div className="form-actions">
          <button type="submit" className="btn-submit" disabled={submitting}>
            {submitting
              ? (lang === 'fr' ? 'Envoi en cours...' : 'Submitting...')
              : (lang === 'fr' ? 'Recevoir le lien de confirmation →' : 'Receive confirmation link →')}
          </button>
        </div>
      </form>
    </div>
  )
}
