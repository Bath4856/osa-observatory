const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

export async function submitAccessRequest(data) {
  const res = await fetch(`${API}/api/v2/participation/tickets`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...data, ticket_type: 'DEMANDE_ACCES' })
  })
  if (!res.ok) throw new Error('ticket submission failed')
  return res.json()
}
