import { useState } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Login.css'
import './ConfirmEmail.css'

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

function checkPasswordRules(pw) {
  return {
    length: pw.length >= 8,
    lower: /[a-z]/.test(pw),
    upper: /[A-Z]/.test(pw),
    digit: /[0-9]/.test(pw),
    special: /[^A-Za-z0-9]/.test(pw),
  }
}

export default function ResetPassword() {
  const [searchParams] = useSearchParams()
  const { lang } = useLang()
  const token = searchParams.get('token')

  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [status, setStatus] = useState('form') // form | submitting | success | error
  const [error, setError] = useState(null)

  const rules = checkPasswordRules(password)
  const allRulesOk = Object.values(rules).every(Boolean)
  const passwordsMatch = password.length > 0 && password === confirmPassword

  async function handleSubmit(e) {
    e.preventDefault()
    setError(null)
    if (!allRulesOk) {
      setError(lang === 'fr' ? "Le mot de passe ne respecte pas encore toutes les règles." : "Password does not meet all the rules yet.")
      return
    }
    if (!passwordsMatch) {
      setError(lang === 'fr' ? "Les deux mots de passe ne correspondent pas." : "Passwords do not match.")
      return
    }
    setStatus('submitting')
    try {
      const res = await fetch(`${API}/api/v1/affiliation/reset-password/${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password }),
      })
      const data = await res.json()
      if (res.ok) {
        setStatus('success')
      } else {
        setStatus('form')
        setError(data.detail?.[lang] || data.detail?.fr || data.detail)
      }
    } catch {
      setStatus('form')
      setError(lang === 'fr' ? "Impossible de contacter le serveur." : "Unable to reach the server.")
    }
  }

  if (!token) {
    return (
      <div className="login-page">
        <div className="login-card">
          <p className="login-error">
            {lang === 'fr' ? "Lien de réinitialisation invalide." : "Invalid reset link."}
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="login-page">
      <div className="login-card">
        {status !== 'success' ? (
          <>
            <h1 className="login-title">
              {lang === 'fr' ? 'Nouveau mot de passe' : 'New password'}
            </h1>
            <form onSubmit={handleSubmit} className="login-form">
              <label className="login-label">
                {lang === 'fr' ? 'Nouveau mot de passe' : 'New password'}
                <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoFocus />
              </label>

              <ul className="confirm-rules">
                <li className={rules.length ? 'ok' : ''}>{lang === 'fr' ? '8 caractères minimum' : 'At least 8 characters'}</li>
                <li className={rules.lower ? 'ok' : ''}>{lang === 'fr' ? 'Une lettre minuscule' : 'One lowercase letter'}</li>
                <li className={rules.upper ? 'ok' : ''}>{lang === 'fr' ? 'Une lettre majuscule' : 'One uppercase letter'}</li>
                <li className={rules.digit ? 'ok' : ''}>{lang === 'fr' ? 'Un chiffre' : 'One digit'}</li>
                <li className={rules.special ? 'ok' : ''}>{lang === 'fr' ? 'Un caractère spécial' : 'One special character'}</li>
              </ul>

              <label className="login-label">
                {lang === 'fr' ? 'Confirmer le mot de passe' : 'Confirm password'}
                <input type="password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} required />
              </label>

              {error && <p className="login-error">{error}</p>}

              <button type="submit" className="login-btn" disabled={status === 'submitting'}>
                {status === 'submitting'
                  ? (lang === 'fr' ? 'Enregistrement...' : 'Saving...')
                  : (lang === 'fr' ? 'Réinitialiser →' : 'Reset →')}
              </button>
            </form>
          </>
        ) : (
          <>
            <h1 className="login-title">
              {lang === 'fr' ? 'Mot de passe réinitialisé' : 'Password reset'}
            </h1>
            <p className="login-sub">
              {lang === 'fr' ? 'Vous pouvez maintenant vous connecter.' : 'You can now log in.'}
            </p>
            <Link to="/login" className="login-btn" style={{ display: 'block', textAlign: 'center', textDecoration: 'none' }}>
              {lang === 'fr' ? 'Se connecter →' : 'Log in →'}
            </Link>
          </>
        )}
      </div>
    </div>
  )
}
