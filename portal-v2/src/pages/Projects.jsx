import { useEffect, useState } from 'react'
import { useParams, useSearchParams, Link } from 'react-router-dom'
import { getProjects } from '../api/projects'
import { useLang } from '../i18n/useLang'
import './Projects.css'

const PILLARS = ['PGEO','PECO','PMIN','PHUM','PENV','PMIL','PMON','PNUM','PRES','PTRA']

export default function Projects() {
  const { iso3 } = useParams()
  const [searchParams] = useSearchParams()
  const pillarFilter = searchParams.get('pillar')
  const { t, lang } = useLang()

  const [projects, setProjects] = useState([])
  const [loading, setLoading] = useState(true)
  const [activePillar, setActivePillar] = useState(pillarFilter || 'ALL')

  useEffect(() => {
    setLoading(true)
    getProjects(iso3)
      .then(data => {
        const arr = Array.isArray(data) ? data
          : data.projects || data.results || []
        setProjects(arr)
      })
      .catch(() => setProjects([]))
      .finally(() => setLoading(false))
  }, [iso3])

  useEffect(() => {
    if (pillarFilter) setActivePillar(pillarFilter)
  }, [pillarFilter])

  const filtered = activePillar === 'ALL'
    ? projects
    : projects.filter(p => p.pillar_code === activePillar)

  return (
    <div className="projects-page">
      <div className="projects-header">
        <div>
          <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
          <h1 className="projects-title">Sovereign Projects</h1>
        </div>
      </div>

      <div className="pillar-tabs">
        <button
          className={`pillar-tab ${activePillar === 'ALL' ? 'active' : ''}`}
          onClick={() => setActivePillar('ALL')}>All</button>
        {PILLARS.map(p => (
          <button key={p}
            className={`pillar-tab ${activePillar === p ? 'active' : ''}`}
            onClick={() => setActivePillar(p)}>{p}</button>
        ))}
      </div>

      {loading ? (
        <div className="page-loading">Loading projects...</div>
      ) : filtered.length === 0 ? (
        <div className="no-projects">No projects available for this selection.</div>
      ) : (
        <div className="projects-grid">
          {filtered.map(project => (
            <Link
              key={project.id || project.project_id}
              to={`/country/${iso3}/projects/${project.id || project.project_id}`}
              className="project-card">
              <div className="card-pillar">{project.pillar_code}</div>
              {project.early_warning && (
                <div className="card-warning">⚠ {project.early_warning}</div>
              )}
              <div className="card-title">
                {lang === 'fr' ? (project.project_name_fr || project.project_name) : project.project_name}
              </div>
              <div className="card-status">
                {project.feasibility_available
                  ? <span className="status-available">Feasibility study available</span>
                  : <span className="status-pending">Opportunity identified</span>}
              </div>
              <div className="card-cta">View project →</div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
