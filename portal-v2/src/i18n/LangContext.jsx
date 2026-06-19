import { createContext, useContext, useState, useCallback } from 'react'
import en from './en.json'
import fr from './fr.json'

const translations = { en, fr }
const LangContext = createContext(null)

export function LangProvider({ children }) {
  const [lang, setLang] = useState(
    localStorage.getItem('osa_lang') || 'en'
  )
  const t = useCallback((key) => {
    const keys = key.split('.')
    let val = translations[lang]
    for (const k of keys) val = val?.[k]
    return val || key
  }, [lang])
  const switchLang = useCallback((l) => {
    localStorage.setItem('osa_lang', l)
    setLang(l)
  }, [])
  return (
    <LangContext.Provider value={{ lang, t, switchLang }}>
      {children}
    </LangContext.Provider>
  )
}

export function useLang() {
  const ctx = useContext(LangContext)
  if (!ctx) throw new Error('useLang must be used within LangProvider')
  return ctx
}
