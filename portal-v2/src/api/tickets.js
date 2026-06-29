const API = import.meta.env.VITE_API_URL || 'https://api.osa-observatory.africa'

const TYPE_MAP = {
  DATA_SIGNAL:     'QUESTION',
  SOURCE_PROPOSAL: 'SUGGESTION',
  METHODOLOGICAL:  'SUGGESTION',
}

// Demande d'affiliation -- endpoint dedie Sprint 30 Lot B
export async function submitAffiliationRequest(data) {
  const res = await fetch(`${API}/api/v1/affiliation/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      last_name:      data.last_name,
      first_name:     data.first_name,
      function_title: data.function_title || null,
      email:          data.email,
      org_name:       data.org_name,
      affiliate_type: data.affiliate_type,
      country:        data.country || null,
      motivation:     data.motivation || null,
    })
  })
  if (!res.ok) {
    const err = await res.json()
    throw new Error(err.detail || 'Affiliation request failed')
  }
  return res.json()
}

// Contributions E-Participation -- tickets publics
export async function submitAccessRequest(data) {
  // Rediriger les demandes d'affiliation vers le bon endpoint
  if (data.contribution_type === 'DEMANDE_AFFILIATION') {
    return submitAffiliationRequest(data)
  }
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
      country_iso3:      data.country    || null,
      indicator_code:    data.indicator  || null,
      pillar_code:       data.pillar     || null,
      source_url:        data.source_url || null,
      contribution_type: data.contribution_type,
    })
  })
  if (!res.ok) throw new Error('ticket submission failed')
  return res.json()
}
