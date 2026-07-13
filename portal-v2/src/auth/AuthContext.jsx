import { createContext, useContext, useState, useCallback } from 'react'

const AuthContext = createContext(null)

const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

function readStoredSession() {
  try {
    const raw = localStorage.getItem('osa_auth')
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function AuthProvider({ children }) {
  const [session, setSession] = useState(readStoredSession())

  const login = useCallback(async (email, password) => {
    const res = await fetch(`${API}/api/v2/affiliates/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    })
    const data = await res.json()
    if (!res.ok) {
      throw new Error(data.detail?.fr || data.detail || 'Connexion impossible.')
    }
    const newSession = {
      token: data.token,
      affiliate_id: data.affiliate_id,
      email: data.email,
      role: data.role,
    }
    localStorage.setItem('osa_auth', JSON.stringify(newSession))
    setSession(newSession)
    return newSession
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('osa_auth')
    setSession(null)
  }, [])

  // Recupere le profil complet (/me), y compris kyc_complete -- utilise
  // par le bandeau de rappel doux et la page Mon espace. Ne modifie pas
  // la session stockee (token/role), juste un appel a la demande.
  const fetchProfile = useCallback(async () => {
    if (!session) return null
    const res = await fetch(`${API}/api/v2/affiliates/auth/me`, {
      headers: { Authorization: `Bearer ${session.token}` },
    })
    if (!res.ok) return null
    return res.json()
  }, [session])

  return (
    <AuthContext.Provider value={{ session, isAuthenticated: !!session, login, logout, fetchProfile }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
