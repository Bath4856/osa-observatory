import { useState } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { submitAccessRequest } from '../api/tickets'
import './Participate.css'

export default function Participate() {
  const [searchParams] = useSearchParams()
  const [form, setForm] = useState({
    name: '', email: '',
    country: searchParams.get('country') || '',
    message: ''
  })
  const [status, setStatus] = useState(null)

  const handleChange = e => setForm(f => ({ ...f, [e.target.name]: e.target.value }))

  const handleSubmit = async e => {
    e.preventDefault()
    try {
      await submitAccessRequest({ ...form, ticket_type: 'SIGNALEMENT' })
      setStatus('success')
    } catch {
      setStatus('error')
    }
  }

  return (
    <div className="participate-page">
      <h1 className="participate-title">E-Participation</h1>
      <p className="participate-intro">
        Contribute to the quality of OSA Observatory data. Report anomalies,
        suggest new data sources, or provide feedback on sovereign indicators.
      </p>

      {form.country && (
        <div className="participate-context">
          Reporting for : <strong>{form.country}</strong>
          <Link to={`/country/${form.country}`} className="ctx-link"> ← Back to country</Link>
        </div>
      )}

      {status === 'success' ? (
        <div className="participate-success">
          Thank you for your contribution. Your signal has been recorded.
        </div>
      ) : (
        <form className="participate-form" onSubmit={handleSubmit}>
          <div className="form-row">
            <label>Name *
              <input name="name" value={form.name} onChange={handleChange} required />
            </label>
            <label>Email *
              <input name="email" type="email" value={form.email} onChange={handleChange} required />
            </label>
          </div>
          <label>Country (optional)
            <input name="country" value={form.country} onChange={handleChange} placeholder="ISO3 code e.g. DZA" />
          </label>
          <label>Message *
            <textarea name="message" value={form.message} onChange={handleChange} rows={5} required
              placeholder="Describe the anomaly, suggestion, or feedback..." />
          </label>
          {status === 'error' && <div className="form-error">Submission failed. Please try again.</div>}
          <button type="submit" className="btn-submit">Submit signal →</button>
        </form>
      )}
    </div>
  )
}
