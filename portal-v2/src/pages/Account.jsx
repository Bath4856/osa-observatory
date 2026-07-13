import { useState, useEffect } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { useLang } from '../i18n/useLang'
import './Account.css'

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

export default function Account() {
  const { session, isAuthenticated, fetchProfile } = useAuth()
  const { lang } = useLang()

  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)

  // Formulaire profil (KYC)
  const [functionTitle, setFunctionTitle] = useState('')
  const [orgName, setOrgName] = useState('')
  const [country, setCountry] = useState('')
  const [profileMsg, setProfileMsg] = useState(null)
  const [savingProfile, setSavingProfile] = useState(false)

  // Formulaire mot de passe
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmNewPassword, setConfirmNewPassword] = useState('')
  const [pwMsg, setPwMsg] = useState(null)
  const [savingPw, setSavingPw] = useState(false)

  useEffect(() => {
    fetchProfile().then((data) => {
      if (data) {
        setProfile(data)
        setFunctionTitle(data.function_title || '')
        setOrgName(data.org_name || '')
        setCountry(data.country || '')
      }
      setLoading(false)
    })
  }, [fetchProfile])

  if (!isAuthenticated) return <Navigate to="/login" replace />

  const pwRules = checkPasswordRules(newPassword)
  const pwRulesOk = Object.values(pwRules).every(Boolean)
  const pwMatch = newPassword.length > 0 && newPassword === confirmNewPassword

  async function handleProfileSubmit(e) {
    e.preventDefault()
    setProfileMsg(null)
    setSavingProfile(true)
    try {
      const res = await fetch(`${API}/api/v2/affiliates/auth/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${session.token}` },
        body: JSON.stringify({ function_title: functionTitle, org_name: orgName, country }),
      })
      const data = await res.json()
      if (res.ok) {
        setProfileMsg({ type: 'ok', text: lang === 'fr' ? 'Profil mis à jour.' : 'Profile updated.' })
        const refreshed = await fetchProfile()
        if (refreshed) setProfile(refreshed)
      } else {
        setProfileMsg({ type: 'err', text: data.detail?.[lang] || data.detail?.fr || data.detail })
      }
    } finally {
      setSavingProfile(false)
    }
  }

  async function handlePasswordSubmit(e) {
    e.preventDefault()
    setPwMsg(null)
    if (!pwRulesOk) {
      setPwMsg({ type: 'err', text: lang === 'fr' ? "Le nouveau mot de passe ne respecte pas encore toutes les règles." : "New password does not meet all the rules yet." })
      return
    }
    if (!pwMatch) {
      setPwMsg({ type: 'err', text: lang === 'fr' ? "Les deux mots de passe ne correspondent pas." : "Passwords do not match." })
      return
    }
    setSavingPw(true)
    try {
      const res = await fetch(`${API}/api/v2/affiliates/auth/me/password`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${session.token}` },
        body: JSON.stringify({ current_password: currentPassword, new_password: newPassword }),
      })
      const data = await res.json()
      if (res.ok) {
        setPwMsg({ type: 'ok', text: lang === 'fr' ? 'Mot de passe modifié.' : 'Password changed.' })
        setCurrentPassword(''); setNewPassword(''); setConfirmNewPassword('')
      } else {
        setPwMsg({ type: 'err', text: data.detail?.[lang] || data.detail?.fr || data.detail })
      }
    } finally {
      setSavingPw(false)
    }
  }

  if (loading) return <div className="account-page"><p>{lang === 'fr' ? 'Chargement...' : 'Loading...'}</p></div>

  return (
    <div className="account-page">
      <h1 className="account-title">{lang === 'fr' ? 'Mon espace' : 'My account'}</h1>
      <p className="account-identity">{profile?.first_name} {profile?.last_name} — {profile?.email}</p>

      <section className="account-section">
        <h2>{lang === 'fr' ? 'Profil' : 'Profile'}</h2>
        <form onSubmit={handleProfileSubmit} className="account-form">
          <label className="account-label">
            {lang === 'fr' ? 'Fonction' : 'Function/title'}
            <input value={functionTitle} onChange={(e) => setFunctionTitle(e.target.value)} placeholder={lang === 'fr' ? 'ex. Chercheur, Analyste...' : 'e.g. Researcher, Analyst...'} />
          </label>
          <label className="account-label">
            {lang === 'fr' ? 'Organisation' : 'Organization'}
            <input value={orgName} onChange={(e) => setOrgName(e.target.value)} />
          </label>
          <label className="account-label">
            {lang === 'fr' ? 'Pays' : 'Country'}
            <input value={country} onChange={(e) => setCountry(e.target.value)} placeholder={lang === 'fr' ? 'ex. Sénégal' : 'e.g. Senegal'} />
          </label>
          {profileMsg && <p className={`account-msg account-msg--${profileMsg.type}`}>{profileMsg.text}</p>}
          <button type="submit" className="account-btn" disabled={savingProfile}>
            {savingProfile ? (lang === 'fr' ? 'Enregistrement...' : 'Saving...') : (lang === 'fr' ? 'Enregistrer' : 'Save')}
          </button>
        </form>
      </section>

      <section className="account-section">
        <h2>{lang === 'fr' ? 'Mot de passe' : 'Password'}</h2>
        <form onSubmit={handlePasswordSubmit} className="account-form">
          <label className="account-label">
            {lang === 'fr' ? 'Mot de passe actuel' : 'Current password'}
            <input type="password" value={currentPassword} onChange={(e) => setCurrentPassword(e.target.value)} required />
          </label>
          <label className="account-label">
            {lang === 'fr' ? 'Nouveau mot de passe' : 'New password'}
            <input type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} required />
          </label>
          <ul className="account-rules">
            <li className={pwRules.length ? 'ok' : ''}>{lang === 'fr' ? '8 caractères minimum' : 'At least 8 characters'}</li>
            <li className={pwRules.lower ? 'ok' : ''}>{lang === 'fr' ? 'Une lettre minuscule' : 'One lowercase letter'}</li>
            <li className={pwRules.upper ? 'ok' : ''}>{lang === 'fr' ? 'Une lettre majuscule' : 'One uppercase letter'}</li>
            <li className={pwRules.digit ? 'ok' : ''}>{lang === 'fr' ? 'Un chiffre' : 'One digit'}</li>
            <li className={pwRules.special ? 'ok' : ''}>{lang === 'fr' ? 'Un caractère spécial' : 'One special character'}</li>
          </ul>
          <label className="account-label">
            {lang === 'fr' ? 'Confirmer le nouveau mot de passe' : 'Confirm new password'}
            <input type="password" value={confirmNewPassword} onChange={(e) => setConfirmNewPassword(e.target.value)} required />
          </label>
          {pwMsg && <p className={`account-msg account-msg--${pwMsg.type}`}>{pwMsg.text}</p>}
          <button type="submit" className="account-btn" disabled={savingPw}>
            {savingPw ? (lang === 'fr' ? 'Enregistrement...' : 'Saving...') : (lang === 'fr' ? 'Changer le mot de passe' : 'Change password')}
          </button>
        </form>
      </section>
    </div>
  )
}
