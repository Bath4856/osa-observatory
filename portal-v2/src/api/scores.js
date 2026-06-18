const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function getCountryScores(iso3) {
  const res = await fetch(`${API}/api/v2/scores/${iso3}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.history || []
}

export async function getCountryPillarScores(iso3) {
  const years = [2020, 2021, 2022, 2023, 2024]
  const results = await Promise.all(
    years.map(y =>
      fetch(`${API}/api/v2/sovereignty/swot?iso3=${iso3}&year=${y}`)
        .then(r => r.ok ? r.json() : [])
        .then(data => {
          const arr = Array.isArray(data) ? data : []
          return arr.filter(d => d.country_iso3 === iso3)
        })
        .catch(() => [])
    )
  )
  return results.flat()
}

export async function getAllScores(year) {
  const res = await fetch(`${API}/api/v2/scores?year=${year || 2024}`)
  if (!res.ok) throw new Error('scores fetch failed')
  const data = await res.json()
  return data.scores || []
}
