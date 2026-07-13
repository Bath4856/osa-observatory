import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { useLang } from '../i18n/useLang'
import './Login.css'

export default function Login() {
  const { login } = useAuth()
  const { lang } = useLang()
  const navigate = useNavigate()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    try {
      await login(email, password)
      navigate('/')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <h1 className="login-title">
          {lang === 'fr' ? 'Connexion affilié' : 'Affiliate login'}
        </h1>
        <p className="login-sub">
          {lang === 'fr'
            ? "Connectez-vous avec l'e-mail et le mot de passe qui vous ont été transmis."
            : 'Log in with the email and password you were given.'}
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

          <label className="login-label">
            {lang === 'fr' ? 'Mot de passe' : 'Password'}
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </label>

          {error && <p className="login-error">{error}</p>}

          <button type="submit" className="login-btn" disabled={loading}>
            {loading
              ? (lang === 'fr' ? 'Connexion...' : 'Signing in...')
              : (lang === 'fr' ? 'Se connecter →' : 'Log in →')}
          </button>
        </form>

        <p className="login-footer-note">
          <Link to="/forgot-password">
            {lang === 'fr' ? 'Mot de passe oublié ?' : 'Forgot password?'}
          </Link>
        </p>

        <p className="login-footer-note">
          {lang === 'fr' ? 'Pas encore affilié ?' : 'Not affiliated yet?'}{' '}
          <Link to="/participate">
            {lang === 'fr' ? 'Demander une affiliation' : 'Request an affiliation'}
          </Link>
        </p>
      </div>
    </div>
  )
}
