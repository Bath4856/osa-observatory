import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Login.css'

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export default function ForgotPassword() {
  const { lang } = useLang()
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    setLoading(true)
    try {
      await fetch(`${API}/api/v1/affiliation/request-password-reset`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      })
    } finally {
      // Toujours afficher le meme message, succes ou echec technique --
      // ne jamais reveler si une adresse existe ou non.
      setSent(true)
      setLoading(false)
    }
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <h1 className="login-title">
          {lang === 'fr' ? 'Mot de passe oublié' : 'Forgot password'}
        </h1>

        {!sent ? (
          <>
            <p className="login-sub">
              {lang === 'fr'
                ? "Indiquez votre e-mail : si un compte y correspond, un lien de réinitialisation vous sera envoyé."
                : "Enter your email: if an account matches, a reset link will be sent to you."}
            </p>
            <form onSubmit={handleSubmit} className="login-form">
              <label className="login-label">
                {lang === 'fr' ? 'E-mail' : 'Email'}
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  autoFocus
                />
              </label>
              <button type="submit" className="login-btn" disabled={loading}>
                {loading
                  ? (lang === 'fr' ? 'Envoi...' : 'Sending...')
                  : (lang === 'fr' ? 'Envoyer le lien →' : 'Send link →')}
              </button>
            </form>
          </>
        ) : (
          <p className="login-sub">
            {lang === 'fr'
              ? "Si cette adresse correspond à un compte, un lien de réinitialisation vient d'être envoyé. Vérifiez votre boîte de réception."
              : "If this address matches an account, a reset link has just been sent. Check your inbox."}
          </p>
        )}

        <p className="login-footer-note">
          <Link to="/login">{lang === 'fr' ? '← Retour à la connexion' : '← Back to login'}</Link>
        </p>
      </div>
    </div>
  )
}
