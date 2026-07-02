// countries.js -- Fiche identite pays
// Source : /opendata/countries/{iso3}/identity
const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getCountryIdentity(iso3) {
  try {
    const res = await fetch(`${API}/opendata/countries/${iso3}/identity`)
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}
