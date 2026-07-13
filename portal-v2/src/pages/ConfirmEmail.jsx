import { useState, useEffect } from 'react'
import { useSearchParams, Link, useNavigate } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import { useAuth } from '../auth/AuthContext'
import logo from '../assets/logo_header.png'
import './ConfirmEmail.css'

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

// Reproduit la politique serveur (api/utils/password_policy.py) pour un
// retour immediat -- l'application reelle de la regle reste cote serveur,
// ceci n'est qu'une aide a la saisie.
function checkPasswordRules(pw) {
  return {
    length: pw.length >= 8,
    lower: /[a-z]/.test(pw),
    upper: /[A-Z]/.test(pw),
    digit: /[0-9]/.test(pw),
    special: /[^A-Za-z0-9]/.test(pw),
  }
}

export default function ConfirmEmail() {
  const [searchParams] = useSearchParams()
  const { lang, switchLang } = useLang()
  const { login } = useAuth()
  const navigate = useNavigate()
  const token = searchParams.get('token')

  const [status, setStatus] = useState(token ? 'loading' : 'error') // loading | form | submitting | success | error
  const [message, setMessage] = useState(
    token ? null : { fr: "Lien de confirmation invalide ou incomplet.", en: "Invalid or incomplete confirmation link." }
  )
  const [identity, setIdentity] = useState(null)
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [functionTitle, setFunctionTitle] = useState('')
  const [country, setCountry] = useState('')
  const [formError, setFormError] = useState(null)

  useEffect(() => {
    if (!token) return
    fetch(`${API}/api/v1/affiliation/confirm-email/${token}/info`)
      .then(async (res) => {
        const data = await res.json()
        if (res.ok) {
          setIdentity(data)
          setStatus('form')
        } else {
          setStatus('error')
          setMessage(data.detail || { fr: "Lien invalide.", en: "Invalid link." })
        }
      })
      .catch(() => {
        setStatus('error')
        setMessage({ fr: "Impossible de contacter le serveur.", en: "Unable to reach the server." })
      })
  }, [token])

  const rules = checkPasswordRules(password)
  const allRulesOk = Object.values(rules).every(Boolean)
  const passwordsMatch = password.length > 0 && password === confirmPassword

  async function handleSubmit(e) {
    e.preventDefault()
    setFormError(null)

    if (!allRulesOk) {
      setFormError(lang === 'fr'
        ? "Le mot de passe ne respecte pas encore toutes les règles ci-dessous."
        : "The password does not yet meet all the rules below.")
      return
    }
    if (!passwordsMatch) {
      setFormError(lang === 'fr' ? "Les deux mots de passe ne correspondent pas." : "The two passwords do not match.")
      return
    }
    if (!functionTitle.trim() || !country.trim()) {
      setFormError(lang === 'fr'
        ? "Fonction et pays sont obligatoires pour finaliser l'inscription."
        : "Function and country are required to complete registration.")
      return
    }

    setStatus('submitting')
    try {
      const res = await fetch(`${API}/api/v1/affiliation/confirm-email/${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password, function_title: functionTitle.trim(), country: country.trim() }),
      })
      const data = await res.json()
      if (res.ok) {
        // Connexion automatique -- le mot de passe vient d'etre choisi,
        // aucune raison de le faire ressaisir sur un ecran separe (retour
        // direct de Theo, session du 11 juillet 2026). Repli sur l'ecran
        // de succes manuel si la connexion automatique echoue pour une
        // raison quelconque -- ne bloque jamais l'utilisateur.
        try {
          await login(identity.email, password)
          navigate('/')
          return
        } catch {
          setStatus('success')
          setMessage(data.message)
        }
      } else if (res.status === 422) {
        // Mot de passe rejete par le serveur -- token non consomme, on
        // reste sur le formulaire pour permettre une nouvelle saisie.
        setStatus('form')
        setFormError(data.detail?.[lang] || data.detail?.fr || data.detail)
      } else {
        setStatus('error')
        setMessage(data.detail || {
          fr: "Une erreur est survenue lors de la confirmation.",
          en: "An error occurred during confirmation."
        })
      }
    } catch {
      setStatus('form')
      setFormError(lang === 'fr'
        ? "Impossible de contacter le serveur. Veuillez réessayer."
        : "Unable to reach the server. Please try again.")
    }
  }

  return (
    <div className="confirm-standalone">
      <header className="confirm-standalone-header">
        <div className="confirm-standalone-brand">
          <img src={logo} alt="OSA Observatory" />
          <div>
            <div className="confirm-standalone-org">OSA Observatory</div>
            <div className="confirm-standalone-sub">Observatoire de la Souveraineté Africaine</div>
          </div>
        </div>
        <div className="confirm-standalone-lang">
          <button className={`lang-btn ${lang==='en'?'active':''}`} onClick={() => switchLang('en')}>EN</button>
          <span className="lang-sep">|</span>
          <button className={`lang-btn ${lang==='fr'?'active':''}`} onClick={() => switchLang('fr')}>FR</button>
        </div>
      </header>

      <div className="confirm-email-page">
      <div className={`confirm-card confirm-card--${status}`}>

        {status === 'loading' && (
          <>
            <div className="confirm-spinner" />
            <p className="confirm-text">{lang === 'fr' ? 'Vérification du lien...' : 'Verifying link...'}</p>
          </>
        )}

        {(status === 'form' || status === 'submitting') && (
          <>
            <h1 className="confirm-title">
              {lang === 'fr' ? 'Finalisez votre inscription' : 'Complete your registration'}
            </h1>
            <p className="confirm-text">
              {lang === 'fr'
                ? "Dernière étape : complétez votre profil et choisissez un mot de passe pour activer votre compte."
                : "Last step: complete your profile and choose a password to activate your account."}
            </p>

            {(identity && (identity.first_name || identity.destination_fr)) && (
              <div className="confirm-context">
                {identity.first_name && (
                  <div className="confirm-context-row">
                    <span className="confirm-context-label">{lang === 'fr' ? 'Compte' : 'Account'}</span>
                    <span className="confirm-context-value">{identity.first_name} {identity.last_name} — {identity.email}</span>
                  </div>
                )}
                {(identity.destination_fr || identity.destination_en) && (
                  <div className="confirm-context-row">
                    <span className="confirm-context-label">{lang === 'fr' ? 'Destination' : 'Destination'}</span>
                    <span className="confirm-context-value">{lang === 'fr' ? identity.destination_fr : identity.destination_en}</span>
                  </div>
                )}
              </div>
            )}

            <form onSubmit={handleSubmit} className="confirm-form">
              <label className="confirm-label">
                {lang === 'fr' ? 'Fonction' : 'Function / title'}
                <input
                  type="text"
                  value={functionTitle}
                  onChange={(e) => setFunctionTitle(e.target.value)}
                  placeholder={lang === 'fr' ? 'ex. Chercheur, Analyste...' : 'e.g. Researcher, Analyst...'}
                  required
                />
              </label>

              <label className="confirm-label">
                {lang === 'fr' ? 'Pays' : 'Country'}
                <input
                  type="text"
                  value={country}
                  onChange={(e) => setCountry(e.target.value)}
                  placeholder={lang === 'fr' ? 'ex. Sénégal' : 'e.g. Senegal'}
                  required
                />
              </label>

              <label className="confirm-label">
                {lang === 'fr' ? 'Mot de passe' : 'Password'}
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoFocus
                  required
                />
              </label>

              <ul className="confirm-rules">
                <li className={rules.length ? 'ok' : ''}>{lang === 'fr' ? '8 caractères minimum' : 'At least 8 characters'}</li>
                <li className={rules.lower ? 'ok' : ''}>{lang === 'fr' ? 'Une lettre minuscule' : 'One lowercase letter'}</li>
                <li className={rules.upper ? 'ok' : ''}>{lang === 'fr' ? 'Une lettre majuscule' : 'One uppercase letter'}</li>
                <li className={rules.digit ? 'ok' : ''}>{lang === 'fr' ? 'Un chiffre' : 'One digit'}</li>
                <li className={rules.special ? 'ok' : ''}>{lang === 'fr' ? 'Un caractère spécial' : 'One special character'}</li>
              </ul>

              <label className="confirm-label">
                {lang === 'fr' ? 'Confirmer le mot de passe' : 'Confirm password'}
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                />
              </label>

              {formError && <p className="confirm-form-error">{formError}</p>}

              <button type="submit" className="confirm-btn" disabled={status === 'submitting'}>
                {status === 'submitting'
                  ? (lang === 'fr' ? 'Activation...' : 'Activating...')
                  : (lang === 'fr' ? 'Activer mon compte →' : 'Activate my account →')}
              </button>
            </form>
          </>
        )}

        {status === 'success' && (
          <>
            <div className="confirm-icon confirm-icon--success">✓</div>
            <h1 className="confirm-title">
              {lang === 'fr' ? 'Compte activé' : 'Account activated'}
            </h1>
            <p className="confirm-text">
              {message?.[lang] || message?.fr}
            </p>
            <Link to="/login" className="confirm-btn">
              {lang === 'fr' ? 'Se connecter →' : 'Log in →'}
            </Link>
          </>
        )}

        {status === 'error' && (
          <>
            <div className="confirm-icon confirm-icon--error">✕</div>
            <h1 className="confirm-title">
              {lang === 'fr' ? 'Confirmation impossible' : 'Confirmation failed'}
            </h1>
            <p className="confirm-text">
              {message?.[lang] || message?.fr}
            </p>
            <Link to="/register" className="confirm-btn confirm-btn--secondary">
              {lang === 'fr' ? 'Faire une nouvelle demande →' : 'Submit a new request →'}
            </Link>
          </>
        )}

      </div>
      </div>
    </div>
  )
}
