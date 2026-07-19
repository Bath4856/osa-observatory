import { useEffect, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { getStructuralObs, getPoaCatalog } from '../api/structural'
import { useLang } from '../i18n/useLang'
import './PoaDetail.css'

// Pas d'annees de publication codees en dur ici : le statut de publication
// (OFFICIEL / PRELIMINAIRE / absent) vient de rf.publication_policy via
// l'API (champ publication_status de chaque ligne). Une annee est "publiee"
// si et seulement si ce champ n'est pas null -- jamais une liste figee cote
// portail qui se perimerait a chaque nouvelle annee ouverte.

const INDICATOR_ORDER = [
  'PHUM_VALUE_CAPTURE',
  'PMIN_VALUE_LEAKAGE',
  'PMIN_SMUGGLING_SIGNAL_RANK'
]

// Adapte une ligne de rf.poa_catalog (une seule fois, bilingue par colonnes
// _fr/_en) vers la forme {label, delta_desc, ...} attendue par le reste du
// composant -- evite de reecrire toute la logique de rendu en aval.
// Source de verite unique : plus aucune donnee en dur cote portail
// (Sprint 31 -- doctrine "tout en base").
function adaptCatalogRow(row, lang) {
  if (!row) return null
  const pick = (base) => row[`${base}_${lang}`]
  return {
    label: lang === 'fr' ? row.title_fr : row.title_en,
    delta_desc: pick('delta_desc'),
    metric_label: pick('metric_label'),
    metric_note: pick('metric_note'),
    source: pick('source'),
    coverage_fr: row.coverage_fr,
    coverage_en: row.coverage_en,
    project_pillar: row.pillar_code,
    warning: (row.warning_fr || row.warning_en) ? { fr: row.warning_fr, en: row.warning_en } : null,
    tendency_up_fr: row.tendency_up_fr, tendency_up_en: row.tendency_up_en,
    tendency_down_fr: row.tendency_down_fr, tendency_down_en: row.tendency_down_en,
    tendency_flat_fr: row.tendency_flat_fr, tendency_flat_en: row.tendency_flat_en,
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function getDeltaClass(value, code) {
  if (value == null) return ''
  // Pour PMIN_VALUE_LEAKAGE et PMIN_SMUGGLING : fort = mauvais
  if (code === 'PMIN_VALUE_LEAKAGE' || code === 'PMIN_SMUGGLING_SIGNAL_RANK') {
    if (value > 70) return 'delta-high'
    if (value > 40) return 'delta-medium'
    return 'delta-low'
  }
  // Pour PHUM_VALUE_CAPTURE : fort = bon
  if (value > 60) return 'delta-low'
  if (value > 30) return 'delta-medium'
  return 'delta-high'
}

function getTendency(rows, pubYears, code) {
  const vals = pubYears
    .map(y => rows.find(r => r.year === y)?.raw_value)
    .filter(v => v != null)
  // Moins de 2 points observés : aucune tendance n'est calculable.
  // A ne jamais confondre avec 'flat' (une tendance reellement stable,
  // calculee a partir de donnees suffisantes) -- le trait d'absence de
  // donnee et la fleche "stable" doivent rester visuellement distincts.
  if (vals.length < 2) return 'insufficient'
  const delta = vals[vals.length - 1] - vals[0]
  const threshold = 3 // % de variation significative
  if (code === 'PHUM_VALUE_CAPTURE') {
    // Pour PHUM, une baisse de rétention est une aggravation
    if (delta < -threshold) return 'up'   // aggravation = fuite augmente
    if (delta > threshold)  return 'down' // amélioration = rétention augmente
  } else {
    if (delta > threshold)  return 'up'   // aggravation = fuite augmente
    if (delta < -threshold) return 'down' // amélioration = fuite diminue
  }
  return 'flat'
}

function getObsStatus(rows, pubYears) {
  const observed = pubYears.filter(y => rows.find(r => r.year === y)?.raw_value != null)
  if (observed.length === 0) return 'COLLECTING'
  if (observed.length < pubYears.length) return 'PARTIAL'
  return 'OBSERVED'
}

function PubBadge({ status, lang }) {
  if (!status) return (
    <span className="poa-pub-badge poa-pub-outside">
      {lang === 'fr' ? 'Hors périmètre' : 'Out of scope'}
    </span>
  )
  const labels = {
    OFFICIAL:    { fr: 'Officiel',     en: 'Official' },
    PRELIMINARY: { fr: 'Préliminaire', en: 'Preliminary' },
  }
  return (
    <span className={`poa-pub-badge poa-pub-${status}`}>
      {labels[status]?.[lang] || status}
    </span>
  )
}

function StatusBadge({ status, lang }) {
  const labels = {
    OBSERVED:   { fr: 'Observé',  en: 'Observed' },
    PARTIAL:    { fr: 'Partiel',  en: 'Partial' },
    COLLECTING: { fr: 'Collecte', en: 'Collecting' },
  }
  const s = status || 'COLLECTING'
  return (
    <span className={`poa-status-badge poa-status-${s}`}>
      {labels[s]?.[lang] || s}
    </span>
  )
}

// ─── Composant fiche indicateur ───────────────────────────────────────────────
function IndicatorDetail({ code, rows, lang, iso3, onBack, catalogRow }) {
  const navigate = useNavigate()
  const cfg = adaptCatalogRow(catalogRow, lang)
  if (!cfg) return null

  // Années affichées : uniquement celles reellement publiees (publication_status
  // non nul, provenant de rf.publication_policy via l'API) -- jamais une fenetre
  // figee. Une annee sans statut de publication n'est simplement pas affichee,
  // plutot que montree comme "Hors périmètre" (aucune valeur ajoutee a l'afficher).
  const allYears = [...new Set(rows.filter(r => r.publication_status != null).map(r => r.year))]
    .sort((a, b) => a - b)

  // Tendance sur les années effectivement publiées
  const pubRowsInCoverage = allYears
  const tendency = getTendency(rows, pubRowsInCoverage, code)

  // Variation brute entre première et dernière valeur observée dans la fenêtre pub
  const pubVals = pubRowsInCoverage
    .map(y => rows.find(r => r.year === y)?.raw_value)
    .filter(v => v != null)
  const firstVal = pubVals[0]
  const lastVal  = pubVals[pubVals.length - 1]
  const variation = (firstVal != null && lastVal != null)
    ? lastVal - firstVal
    : null

  const tendencyText = lang === 'fr'
    ? cfg[`tendency_${tendency}_fr`]
    : cfg[`tendency_${tendency}_en`]

  const tendencyArrowClass = tendency === 'up' ? 'up' : tendency === 'down' ? 'down' : 'flat'
  const tendencyArrow = tendency === 'up' ? '↗' : tendency === 'down' ? '↘' : '→'

  return (
    <div className="poa-block poa-indicator-block">
      <h2 className="poa-block-title">{cfg.label}</h2>

      <div className="poa-indicator-meta">
        <div className="poa-indicator-meta-item">
          <span className="poa-meta-label">{lang === 'fr' ? 'Source primaire' : 'Primary source'}</span>
          <span className="poa-meta-value">{cfg.source}</span>
        </div>
        <div className="poa-indicator-meta-item">
          <span className="poa-meta-label">{lang === 'fr' ? 'Couverture' : 'Coverage'}</span>
          <span className="poa-meta-value">{lang === 'fr' ? cfg.coverage_fr : cfg.coverage_en}</span>
        </div>
        <div className="poa-indicator-meta-item">
          <span className="poa-meta-label">{lang === 'fr' ? 'Mesure' : 'Metric'}</span>
          <span className="poa-meta-value">{cfg.metric_label}</span>
        </div>
      </div>

      <p className="poa-block-text" style={{ marginBottom: 16 }}>{cfg.delta_desc}</p>

      {cfg.warning && (
        <div className="poa-note-warning">
          ⚠ {cfg.warning[lang] || cfg.warning.fr}
        </div>
      )}

      {/* Tableau de trajectoire */}
      <div className="poa-trajectory-section">
        <h3 className="poa-trajectory-title">
          {lang === 'fr'
            ? `Trajectoire observée — ${allYears[0]}–${allYears[allYears.length - 1]}`
            : `Observed trajectory — ${allYears[0]}–${allYears[allYears.length - 1]}`}
        </h3>
        <table className="poa-trajectory-table">
          <thead>
            <tr>
              <th>{lang === 'fr' ? 'Année' : 'Year'}</th>
              <th>{cfg.metric_label}</th>
              <th>{lang === 'fr' ? 'Statut de publication' : 'Publication status'}</th>
            </tr>
          </thead>
          <tbody>
            {allYears.map(y => {
              const row = rows.find(r => r.year === y)
              const val = row?.raw_value
              const pubStatus = row?.publication_status || null
              // allYears ne contient que des annees avec publication_status
              // reel (cf. filtre plus haut) -- jamais "Hors périmètre" ici.
              const rowClass = pubStatus === 'OFFICIAL' ? 'row-official' : 'row-preliminary'

              return (
                <tr key={y} className={rowClass}>
                  <td><strong>{y}</strong></td>
                  <td>
                    {val != null
                      ? <span className={`poa-delta-value ${getDeltaClass(val, code)}`}>
                          {val.toFixed(1)}
                        </span>
                      : <span className="poa-not-observed">
                          {lang === 'fr' ? 'Non observé' : 'Not observed'}
                        </span>
                    }
                  </td>
                  <td><PubBadge status={pubStatus} lang={lang} /></td>
                </tr>
              )
            })}
          </tbody>
        </table>

        {/* Note de lecture */}
        <p style={{ fontSize: '.82rem', color: 'var(--color-muted)', marginTop: 8, fontStyle: 'italic' }}>
          {cfg.metric_note}
        </p>
      </div>

      {/* Bilan de tendance */}
      {pubVals.length >= 2 && (
        <div className="poa-tendency-block">
          <div className="poa-tendency-label">
            {lang === 'fr' ? 'Lecture de la tendance' : 'Trend reading'}
          </div>
          <div className="poa-tendency-text">
            <span className={`poa-tendency-arrow ${tendencyArrowClass}`}>{tendencyArrow}</span>
            {tendencyText}
            {variation != null && (
              <span style={{ marginLeft: 8, fontWeight: 600 }}>
                ({variation >= 0 ? '+' : ''}{variation.toFixed(1)} pts)
              </span>
            )}
          </div>
        </div>
      )}

      {/* Retour vers la liste -- plutot qu'un lien vers les projets, pas
          necessaire a ce stade : l'usager peut vouloir consulter une autre
          observation, pas forcement les projets structurants du pilier */}
      <button className="poa-projects-link" style={{ border: 'none', cursor: 'pointer', fontFamily: 'inherit', fontSize: 'inherit' }} onClick={onBack}>
        {lang === 'fr' ? '← Voir une autre observation' : '← View another observation'}
      </button>
    </div>
  )
}

// ─── Page principale ──────────────────────────────────────────────────────────
export default function PoaDetail() {
  const { iso3 } = useParams()
  const { lang } = useLang()
  const [data, setData] = useState(null)
  const [catalog, setCatalog] = useState(null)
  const [selected, setSelected] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Catalogue POA -- independant du pays, charge une seule fois
  useEffect(() => {
    getPoaCatalog()
      .then(c => setCatalog(c))
      .catch(() => setCatalog([]))
  }, [])

  useEffect(() => {
    setLoading(true)
    setError(null)
    setSelected(null)
    getStructuralObs(iso3)
      .then(d => setData(d))
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading || catalog === null) return <div className="page-loading">{lang === 'fr' ? 'Chargement...' : 'Loading...'}</div>
  if (error)   return <div className="page-error">{lang === 'fr' ? 'Erreur' : 'Error'}: {error}</div>

  // Grouper par indicateur
  const byIndicator = {}
  if (data) {
    data.forEach(row => {
      if (!byIndicator[row.indicator_code]) byIndicator[row.indicator_code] = []
      byIndicator[row.indicator_code].push(row)
    })
  }
  const hasData = Object.keys(byIndicator).length > 0
  const catalogByCode = {}
  catalog.forEach(row => { catalogByCode[row.indicator_code] = row })

  return (
    <div className="poa-detail-page">
      <div className="poa-detail-header">
        <h1 className="poa-detail-title">
          {lang === 'fr' ? 'POA — Phénomènes Observables Autonomes' : 'POA — Autonomous Observable Phenomena'} — {iso3}
        </h1>
        <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
      </div>

      {/* Présentation doctrinale -- uniquement sur la vue liste, pas repetee
          a chaque fiche indicateur (evite la duplication signalee) */}
      {!selected && (
        <div className="poa-block poa-block-about">
          <h2 className="poa-block-title">
            {lang === 'fr' ? 'Phénomènes Observables Autonomes' : 'Autonomous Observable Phenomena'}
          </h2>
          <p className="poa-block-text">
            {lang === 'fr'
              ? "Un POA est un phénomène objectivable, reproductible et mesurable, susceptible d'affecter l'exercice effectif de la souveraineté. Ces observations documentent des déltas mesurables — des écarts entre ce qu'un État déclare et ce que les données primaires révèlent. Chaque observation repose sur une source unique, auditée et reproductible. Elles ne produisent ni indice, ni score, ni classement, et ne constituent pas un jugement sur les politiques publiques."
              : "A POA is an objectifiable, reproducible and measurable phenomenon likely to affect the effective exercise of sovereignty. These observations document measurable deltas — gaps between what a state declares and what primary data reveals. Each observation relies on a single, audited and reproducible source. They produce no index, score or ranking, and do not constitute a judgment on public policy."}
          </p>
        </div>
      )}

      {!hasData ? (
        <p className="poa-detail-empty">
          {lang === 'fr' ? 'Aucune observation disponible pour ce pays.' : 'No observations available for this country.'}
        </p>
      ) : (
        <>
          {/* Vue synthétique */}
          {!selected && (
            <div className="poa-block">
              <h2 className="poa-block-title">
                {lang === 'fr' ? 'Observations disponibles' : 'Available observations'}
              </h2>
              <table className="poa-obs-table">
                <thead>
                  <tr>
                    <th>{lang === 'fr' ? 'Observation' : 'Observation'}</th>
                    <th>{lang === 'fr' ? 'Ce qui est mesuré' : 'What is measured'}</th>
                    <th>{lang === 'fr' ? 'Statut' : 'Status'}</th>
                    <th>{lang === 'fr' ? 'Tendance' : 'Trend'}</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {INDICATOR_ORDER.map(code => {
                    const rows = byIndicator[code]
                    if (!rows) return null
                    const cfg = adaptCatalogRow(catalogByCode[code], lang)
                    const pubInCov = [...new Set(rows.filter(r => r.publication_status != null).map(r => r.year))]
                    const status = getObsStatus(rows, pubInCov)
                    const tendency = getTendency(rows, pubInCov, code)
                    const insufficient = tendency === 'insufficient'
                    const arrow = insufficient
                      ? (lang === 'fr' ? 'n/d' : 'n/a')
                      : tendency === 'up' ? '↗' : tendency === 'down' ? '↘' : '→'
                    const arrowColor = insufficient
                      ? 'var(--color-muted)'
                      : tendency === 'up' ? '#B00020' : tendency === 'down' ? 'var(--color-primary)' : 'var(--color-accent)'
                    return (
                      <tr key={code}>
                        <td>
                          <span className="poa-obs-name">{cfg?.label || code}</span>
                          <span className="poa-obs-pillar">{rows[0]?.pillar_code}</span>
                        </td>
                        <td>
                          <span className="poa-obs-delta">{cfg?.metric_label}</span>
                        </td>
                        <td><StatusBadge status={status} lang={lang} /></td>
                        <td style={{
                          fontSize: insufficient ? '0.85rem' : '1.3rem',
                          fontStyle: insufficient ? 'italic' : 'normal',
                          textAlign: 'center',
                          color: arrowColor,
                        }} title={insufficient ? (lang === 'fr' ? 'Pas assez de données pour calculer une tendance' : 'Not enough data to compute a trend') : undefined}>
                          {arrow}
                        </td>
                        <td>
                          <button className="poa-btn-voir" onClick={() => setSelected(code)}>
                            {lang === 'fr' ? 'Voir →' : 'View →'}
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}

          {/* Vue détail indicateur */}
          {selected && (
            <>
              <button className="poa-back-top" onClick={() => setSelected(null)}>
                ← {lang === 'fr' ? 'Toutes les observations' : 'All observations'}
              </button>
              <IndicatorDetail
                code={selected}
                rows={byIndicator[selected] || []}
                lang={lang}
                iso3={iso3}
                onBack={() => setSelected(null)}
                catalogRow={catalogByCode[selected]}
              />
            </>
          )}
        </>
      )}

      <p className="poa-disclaimer">
        {lang === 'fr'
          ? "Les POA (Phénomènes Observables Autonomes) ne constituent pas un jugement sur la gouvernance des États. Ils documentent des phénomènes objectivables dont l'analyse et les décisions relèvent de la responsabilité souveraine des États, des chercheurs et des institutions."
          : "POA (Autonomous Observable Phenomena) do not constitute a judgment on state governance. They document objective phenomena whose analysis and decisions are the sovereign responsibility of states, researchers, and institutions."}
      </p>
    </div>
  )
}
