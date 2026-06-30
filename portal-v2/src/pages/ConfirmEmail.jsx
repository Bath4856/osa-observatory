import { useEffect, useState } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './ConfirmEmail.css'

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export default function ConfirmEmail() {
  const [searchParams] = useSearchParams()
  const { lang } = useLang()
  const token = searchParams.get('token')

  const [status, setStatus] = useState('loading') // loading | success | error
  const [message, setMessage] = useState(null)

  useEffect(() => {
    if (!token) {
      setStatus('error')
      setMessage({
        fr: "Lien de confirmation invalide ou incomplet.",
        en: "Invalid or incomplete confirmation link."
      })
      return
    }

    fetch(`${API}/api/v1/affiliation/confirm-email/${token}`)
      .then(async (res) => {
        const data = await res.json()
        if (res.ok) {
          setStatus('success')
          setMessage(data.message)
        } else {
          setStatus('error')
          setMessage(data.detail || {
            fr: "Une erreur est survenue lors de la confirmation.",
            en: "An error occurred during confirmation."
          })
        }
      })
      .catch(() => {
        setStatus('error')
        setMessage({
          fr: "Impossible de contacter le serveur. Veuillez réessayer plus tard.",
          en: "Unable to reach the server. Please try again later."
        })
      })
  }, [token])

  return (
    <div className="confirm-email-page">
      <div className={`confirm-card confirm-card--${status}`}>

        {status === 'loading' && (
          <>
            <div className="confirm-spinner" />
            <h1 className="confirm-title">
              {lang === 'fr' ? 'Confirmation en cours...' : 'Confirming...'}
            </h1>
            <p className="confirm-text">
              {lang === 'fr'
                ? "Veuillez patienter pendant que nous confirmons votre adresse email."
                : "Please wait while we confirm your email address."}
            </p>
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
            <Link to="/participate" className="confirm-btn">
              {lang === 'fr' ? "Accéder à l'espace de contribution →" : 'Access contribution space →'}
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
  )
}
