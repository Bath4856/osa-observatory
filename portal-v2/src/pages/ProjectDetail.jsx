import { useEffect, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { getProjects } from '../api/projects'
import { useLang } from '../i18n/useLang'
import './ProjectDetail.css'

export default function ProjectDetail() {
  const { iso3, id } = useParams()
  const { lang, t } = useLang()
  const navigate = useNavigate()
  const [project, setProject] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getProjects(iso3)
      .then(data => {
        const arr = Array.isArray(data) ? data : data.projects || data.results || []
        const found = arr.find(p => String(p.id || p.project_id) === String(id))
        setProject(found || null)
      })
      .catch(() => setProject(null))
      .finally(() => setLoading(false))
  }, [iso3, id])

  if (loading) return <div className="page-loading">{t('common.loading')}</div>
  if (!project) return <div className="page-error">Project not found.</div>

  const name = lang === 'fr'
    ? (project.project_name_fr || project.project_name)
    : project.project_name

  const desc = lang === 'fr'
    ? (project.description_fr || project.description)
    : project.description

  return (
    <div className="project-detail-page">
      <div className="detail-breadcrumb">
        <Link to={`/country/${iso3}`}>{iso3}</Link>
        <span> / </span>
        <Link to={`/country/${iso3}/projects?pillar=${project.pillar_code}`}>
          {project.pillar_code}
        </Link>
        <span> / </span>
        <span>{name}</span>
      </div>

      <div className="detail-header">
        <span className="detail-pillar">{project.pillar_code}</span>
        <h1 className="detail-title">{name}</h1>
        {project.early_warning && (
          <div className="detail-warning">⚠ {project.early_warning}</div>
        )}
      </div>

      <div className="detail-body">
        <div className="detail-description">
          <h2>Description</h2>
          <p>{desc || 'No description available.'}</p>
        </div>

        <div className="detail-premium">
          <div className="premium-block">
            <h2>Feasibility Study</h2>
            {project.feasibility_available ? (
              <>
                <p className="premium-preview">{project.feasibility_summary || 'Feasibility study available for this project.'}</p>
                <div className="premium-gate">
                  <p>Full study available for SUBSCRIBER and ADVANCED affiliates.</p>
                  <button
                    className="btn-request"
                    onClick={() => navigate(`/register?project=${id}&country=${iso3}&pillar=${project.pillar_code}`)}>
                    {t('register.title')} →
                  </button>
                </div>
              </>
            ) : (
              <p className="premium-na">Feasibility study not yet available.</p>
            )}
          </div>

          <div className="premium-block">
            <h2>Proof of Concept (POC)</h2>
            {project.poc_available ? (
              <>
                <p className="premium-preview">{project.poc_summary || 'POC available for this project.'}</p>
                <div className="premium-gate">
                  <p>Full POC available for ADVANCED affiliates.</p>
                  <button
                    className="btn-request"
                    onClick={() => navigate(`/register?project=${id}&country=${iso3}&pillar=${project.pillar_code}`)}>
                    {t('register.title')} →
                  </button>
                </div>
              </>
            ) : (
              <p className="premium-na">POC not yet available.</p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
