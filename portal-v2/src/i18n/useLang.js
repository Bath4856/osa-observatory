import { useState, useCallback } from 'react'
import en from './en.json'
import fr from './fr.json'

const translations = { en, fr }

export function useLang() {
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

  return { lang, t, switchLang }
}
