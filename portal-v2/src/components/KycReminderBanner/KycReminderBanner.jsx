import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../../auth/AuthContext'
import { useLang } from '../../i18n/useLang'
import './KycReminderBanner.css'

// Rappel doux, jamais bloquant (decision du 11 juillet 2026 : "le moins
// contraignant"). Disparait pour la session en cours si l'utilisateur le
// ferme -- ne revient qu'a la prochaine connexion tant que le profil
// reste incomplet.
export default function KycReminderBanner() {
  const { isAuthenticated, fetchProfile } = useAuth()
  const { lang } = useLang()
  const [showBanner, setShowBanner] = useState(false)
  const [dismissed, setDismissed] = useState(false)

  useEffect(() => {
    if (!isAuthenticated) {
      setShowBanner(false)
      return
    }
    fetchProfile().then((data) => {
      if (data && data.kyc_complete === false) setShowBanner(true)
    })
  }, [isAuthenticated, fetchProfile])

  if (!showBanner || dismissed) return null

  return (
    <div className="kyc-banner">
      <span>
        {lang === 'fr'
          ? 'Votre profil est incomplet (fonction, pays).'
          : 'Your profile is incomplete (function, country).'}{' '}
        <Link to="/mon-espace">{lang === 'fr' ? 'Le compléter →' : 'Complete it →'}</Link>
      </span>
      <button className="kyc-banner-close" onClick={() => setDismissed(true)} aria-label="Fermer">×</button>
    </div>
  )
}
