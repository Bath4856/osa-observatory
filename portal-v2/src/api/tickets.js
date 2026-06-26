const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

const TYPE_MAP = {
  DATA_SIGNAL:    'QUESTION',
  SOURCE_PROPOSAL: 'SUGGESTION',
  METHODOLOGICAL:  'SUGGESTION',
}

export async function submitAccessRequest(data) {
  const ticket_type = TYPE_MAP[data.contribution_type] || 'QUESTION'
  const subject = data.contribution_type + (data.indicator ? ' -- ' + data.indicator : data.pillar ? ' -- ' + data.pillar : data.country ? ' -- ' + data.country : '')
  const res = await fetch(`${API}/api/v1/tickets`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name:              data.name,
      email:             data.email,
      ticket_type:       ticket_type,
      subject:           subject,
      description:       data.message,
      country_iso3:      data.country   || null,
      indicator_code:    data.indicator || null,
      pillar_code:       data.pillar    || null,
      source_url:        data.source_url || null,
      contribution_type: data.contribution_type,
    })
  })
  return res.json()
}
