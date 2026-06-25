import { useEffect, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { getStructuralObs } from '../api/structural'
import { useLang } from '../i18n/useLang'
import './IosaDetail.css'

// Années de publication officielle OSA
const PUB_YEARS = [2020, 2021, 2022, 2023, 2024]

// ─── Configuration par indicateur ─────────────────────────────────────────────
// Chaque indicateur a :
// - un libellé public (sans jargon technique)
// - une description du delta qu'il mesure
// - le nom de la colonne métrique et son unité
// - la couverture géographique et temporelle
// - une note de lecture pour l'usager
// - un lien vers les projets structurants pertinents
const INDICATOR_CONFIG = {
  PHUM_VALUE_CAPTURE: {
    fr: {
      label: 'Capture de valeur du capital humain',
      delta_desc: "Mesure l'écart entre le capital humain formé sur le territoire et celui qui y reste. Un delta négatif croissant signale une hémorragie de compétences — médecins, ingénieurs, cadres qui quittent le pays après leur formation.",
      metric_label: 'Rétention observée (%)',
      metric_note: 'Part du capital humain formé retenu sur le territoire. Un chiffre en baisse indique que la fuite s\'accélère.',
      source: 'Banque mondiale (WB SH.MED.PHYS.ZS + SE.TER.ENRR)',
      coverage_fr: '54 pays · 2010–2024',
      coverage_en: '54 countries · 2010–2024',
      project_pillar: 'PHUM',
      warning: null,
      tendency_up_fr: "La rétention du capital humain se dégrade sur la période — le pays perd proportionnellement plus de compétences formées qu'il n'en retient.",
      tendency_up_en: "Human capital retention is deteriorating over the period — the country is losing a proportionally higher share of its trained skills.",
      tendency_down_fr: "La rétention du capital humain s'améliore sur la période — une part croissante des compétences formées reste sur le territoire.",
      tendency_down_en: "Human capital retention is improving over the period — a growing share of trained skills remains on the territory.",
      tendency_flat_fr: "La rétention du capital humain est stable sur la période observée.",
      tendency_flat_en: "Human capital retention is stable over the observed period.",
    },
    en: {
      label: 'Human capital value capture',
      delta_desc: "Measures the gap between human capital trained on the territory and human capital that stays. A growing negative delta signals a brain drain — doctors, engineers, executives leaving the country after training.",
      metric_label: 'Observed retention (%)',
      metric_note: 'Share of trained human capital retained on the territory. A declining figure indicates accelerating outflow.',
      source: 'World Bank (WB SH.MED.PHYS.ZS + SE.TER.ENRR)',
      coverage_fr: '54 pays · 2010–2024',
      coverage_en: '54 countries · 2010–2024',
      project_pillar: 'PHUM',
      warning: null,
      tendency_up_fr: "La rétention du capital humain se dégrade sur la période.",
      tendency_up_en: "Human capital retention is deteriorating over the period.",
      tendency_down_fr: "La rétention du capital humain s'améliore sur la période.",
      tendency_down_en: "Human capital retention is improving over the period.",
      tendency_flat_fr: "La rétention du capital humain est stable sur la période observée.",
      tendency_flat_en: "Human capital retention is stable over the observed period.",
    }
  },
  PMIN_VALUE_LEAKAGE: {
    fr: {
      label: 'Fuite de valeur minière',
      delta_desc: "Mesure l'écart entre ce que les partenaires commerciaux déclarent avoir reçu et ce que le pays déclare avoir exporté, sur les minerais stratégiques. Ce delta représente la valeur qui quitte le territoire sans être déclarée ni capturée — une hémorragie commerciale mesurable.",
      metric_label: 'Fuite déclarée (%)',
      metric_note: 'Pourcentage de la valeur minérale reçue par les partenaires qui n\'a pas été déclarée à l\'export par le pays. Plus ce chiffre est élevé, plus l\'hémorragie est importante.',
      source: 'CEPII BACI HS92 (HS26 + HS27 + HS71)',
      coverage_fr: '54 pays · 2010–2024',
      coverage_en: '54 countries · 2010–2024',
      project_pillar: 'PMIN',
      warning: null,
      tendency_up_fr: "La fuite de valeur minière s'aggrave sur la période — une proportion croissante des minerais exportés échappe à la déclaration officielle.",
      tendency_up_en: "Mineral value leakage is worsening over the period — a growing share of exported minerals escapes official declaration.",
      tendency_down_fr: "La fuite de valeur minière se réduit sur la période — la part des minerais non déclarés diminue.",
      tendency_down_en: "Mineral value leakage is decreasing over the period — the share of undeclared minerals is declining.",
      tendency_flat_fr: "La fuite de valeur minière est stable sur la période observée.",
      tendency_flat_en: "Mineral value leakage is stable over the observed period.",
    },
    en: {
      label: 'Mineral value leakage',
      delta_desc: "Measures the gap between what trading partners declare having received and what the country declares having exported, on strategic minerals. This delta represents value leaving the territory undeclared and uncaptured — a measurable commercial hemorrhage.",
      metric_label: 'Declared leakage (%)',
      metric_note: 'Percentage of mineral value received by partners that was not declared as an export by the country. The higher this figure, the greater the hemorrhage.',
      source: 'CEPII BACI HS92 (HS26 + HS27 + HS71)',
      coverage_fr: '54 pays · 2010–2024',
      coverage_en: '54 countries · 2010–2024',
      project_pillar: 'PMIN',
      warning: null,
      tendency_up_fr: "La fuite de valeur minière s'aggrave sur la période.",
      tendency_up_en: "Mineral value leakage is worsening over the period.",
      tendency_down_fr: "La fuite de valeur minière se réduit sur la période.",
      tendency_down_en: "Mineral value leakage is decreasing over the period.",
      tendency_flat_fr: "La fuite de valeur minière est stable sur la période observée.",
      tendency_flat_en: "Mineral value leakage is stable over the observed period.",
    }
  },
  PMIN_SMUGGLING_SIGNAL_RANK: {
    fr: {
      label: 'Signal de contrebande minière',
      delta_desc: "Mesure l'écart entre la production minérale estimée et les flux commerciaux déclarés. Un rang élevé indique que l'écart entre production et déclaration est suspect — une configuration méritant une investigation complémentaire. Cet indicateur ne désigne aucune responsabilité.",
      metric_label: 'Rang de suspicion',
      metric_note: 'Rang ordinal construit à partir de l\'écart production/déclaration. Un rang élevé signale une configuration atypique — pas une certitude de contrebande.',
      source: 'BACI × USGS (MIN_PRD_*)',
      coverage_fr: '37 pays · 2016–2021',
      coverage_en: '37 countries · 2016–2021',
      project_pillar: 'PMIN',
      warning: {
        fr: "Série partielle — couverture 2016–2021 pour 37 pays. Les années hors de cette fenêtre n'ont pas de données observées et ne sont pas publiées.",
        en: "Partial series — 2016–2021 coverage for 37 countries. Years outside this window have no observed data and are not published.",
      },
      tendency_up_fr: "Le rang de suspicion s'aggrave sur la période — l'écart entre production estimée et flux déclarés s'élargit.",
      tendency_up_en: "The suspicion rank is worsening over the period — the gap between estimated production and declared flows is widening.",
      tendency_down_fr: "Le rang de suspicion diminue sur la période — l'écart entre production estimée et flux déclarés se réduit.",
      tendency_down_en: "The suspicion rank is decreasing over the period — the gap between estimated production and declared flows is narrowing.",
      tendency_flat_fr: "Le rang de suspicion est stable sur la période observée.",
      tendency_flat_en: "The suspicion rank is stable over the observed period.",
    },
    en: {
      label: 'Mineral smuggling signal',
      delta_desc: "Measures the gap between estimated mineral production and declared trade flows. A high rank indicates that the gap between production and declaration is suspicious — a configuration warranting further investigation. This indicator assigns no responsibility.",
      metric_label: 'Suspicion rank',
      metric_note: 'Ordinal rank built from the production/declaration gap. A high rank signals an atypical configuration — not a certainty of smuggling.',
      source: 'BACI × USGS (MIN_PRD_*)',
      coverage_fr: '37 pays · 2016–2021',
      coverage_en: '37 countries · 2016–2021',
      project_pillar: 'PMIN',
      warning: {
        fr: "Série partielle — couverture 2016–2021 pour 37 pays. Les années hors de cette fenêtre n'ont pas de données observées et ne sont pas publiées.",
        en: "Partial series — 2016–2021 coverage for 37 countries. Years outside this window have no observed data and are not published.",
      },
      tendency_up_fr: "Le rang de suspicion s'aggrave sur la période.",
      tendency_up_en: "The suspicion rank is worsening over the period.",
      tendency_down_fr: "Le rang de suspicion diminue sur la période.",
      tendency_down_en: "The suspicion rank is decreasing over the period.",
      tendency_flat_fr: "Le rang de suspicion est stable sur la période observée.",
      tendency_flat_en: "The suspicion rank is stable over the observed period.",
    }
  }
}

const INDICATOR_ORDER = [
  'PHUM_VALUE_CAPTURE',
  'PMIN_VALUE_LEAKAGE',
  'PMIN_SMUGGLING_SIGNAL_RANK'
]

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
  if (vals.length < 2) return 'flat'
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

function isInCoverage(year, code) {
  if (code === 'PMIN_SMUGGLING_SIGNAL_RANK') return year >= 2016 && year <= 2021
  return year >= 2010 && year <= 2024
}

function PubBadge({ status, lang }) {
  if (!status) return (
    <span className="iosa-pub-badge iosa-pub-outside">
      {lang === 'fr' ? 'Hors périmètre' : 'Out of scope'}
    </span>
  )
  const labels = {
    OFFICIAL:    { fr: 'Officiel',     en: 'Official' },
    PRELIMINARY: { fr: 'Préliminaire', en: 'Preliminary' },
  }
  return (
    <span className={`iosa-pub-badge iosa-pub-${status}`}>
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
    <span className={`iosa-status-badge iosa-status-${s}`}>
      {labels[s]?.[lang] || s}
    </span>
  )
}

// ─── Composant fiche indicateur ───────────────────────────────────────────────
function IndicatorDetail({ code, rows, lang, iso3 }) {
  const navigate = useNavigate()
  const cfg = INDICATOR_CONFIG[code]?.[lang]
  if (!cfg) return null

  // Années affichées : uniquement celles dans la couverture de la source
  const allYears = [...new Set(rows.map(r => r.year))]
    .filter(y => isInCoverage(y, code))
    .sort((a, b) => a - b)

  // Tendance sur les années de publication
  const pubRowsInCoverage = PUB_YEARS.filter(y => isInCoverage(y, code))
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
    <div className="iosa-block iosa-indicator-block">
      <h2 className="iosa-block-title">{cfg.label}</h2>

      <div className="iosa-indicator-meta">
        <div className="iosa-indicator-meta-item">
          <span className="iosa-meta-label">{lang === 'fr' ? 'Source primaire' : 'Primary source'}</span>
          <span className="iosa-meta-value">{cfg.source}</span>
        </div>
        <div className="iosa-indicator-meta-item">
          <span className="iosa-meta-label">{lang === 'fr' ? 'Couverture' : 'Coverage'}</span>
          <span className="iosa-meta-value">{lang === 'fr' ? cfg.coverage_fr : cfg.coverage_en}</span>
        </div>
        <div className="iosa-indicator-meta-item">
          <span className="iosa-meta-label">{lang === 'fr' ? 'Mesure' : 'Metric'}</span>
          <span className="iosa-meta-value">{cfg.metric_label}</span>
        </div>
      </div>

      <p className="iosa-block-text" style={{ marginBottom: 16 }}>{cfg.delta_desc}</p>

      {cfg.warning && (
        <div className="iosa-note-warning">
          ⚠ {cfg.warning[lang] || cfg.warning.fr}
        </div>
      )}

      {/* Tableau de trajectoire */}
      <div className="iosa-trajectory-section">
        <h3 className="iosa-trajectory-title">
          {lang === 'fr'
            ? `Trajectoire observée — ${allYears[0]}–${allYears[allYears.length - 1]}`
            : `Observed trajectory — ${allYears[0]}–${allYears[allYears.length - 1]}`}
        </h3>
        <table className="iosa-trajectory-table">
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
              const isPub = PUB_YEARS.includes(y)
              const rowClass = pubStatus === 'OFFICIAL' ? 'row-official'
                : pubStatus === 'PRELIMINARY' ? 'row-preliminary'
                : isPub ? 'row-official' : 'row-outside'

              return (
                <tr key={y} className={rowClass}>
                  <td><strong>{y}</strong></td>
                  <td>
                    {val != null
                      ? <span className={`iosa-delta-value ${getDeltaClass(val, code)}`}>
                          {val.toFixed(1)}
                        </span>
                      : <span className="iosa-not-observed">
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
        <div className="iosa-tendency-block">
          <div className="iosa-tendency-label">
            {lang === 'fr' ? 'Lecture de la tendance' : 'Trend reading'}
          </div>
          <div className="iosa-tendency-text">
            <span className={`iosa-tendency-arrow ${tendencyArrowClass}`}>{tendencyArrow}</span>
            {tendencyText}
            {variation != null && (
              <span style={{ marginLeft: 8, fontWeight: 600 }}>
                ({variation >= 0 ? '+' : ''}{variation.toFixed(1)} pts)
              </span>
            )}
          </div>
        </div>
      )}

      {/* Lien projets structurants */}
      <Link
        to={`/country/${iso3}/projects?pillar=${cfg.project_pillar}`}
        className="iosa-projects-link">
        {lang === 'fr' ? '→ Projets structurants associés' : '→ Associated structural projects'}
      </Link>
    </div>
  )
}

// ─── Page principale ──────────────────────────────────────────────────────────
export default function IosaDetail() {
  const { iso3 } = useParams()
  const { lang } = useLang()
  const [data, setData] = useState(null)
  const [selected, setSelected] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    setSelected(null)
    getStructuralObs(iso3)
      .then(d => setData(d))
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [iso3])

  if (loading) return <div className="page-loading">{lang === 'fr' ? 'Chargement...' : 'Loading...'}</div>
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

  return (
    <div className="iosa-detail-page">
      <div className="iosa-detail-header">
        <h1 className="iosa-detail-title">
          {lang === 'fr' ? 'Observations Souveraines' : 'Sovereign Observations'} — {iso3}
        </h1>
        <Link to={`/country/${iso3}`} className="back-link">← {iso3}</Link>
      </div>

      {/* Présentation doctrinale */}
      <div className="iosa-block iosa-block-about">
        <h2 className="iosa-block-title">
          {lang === 'fr' ? 'Observations Souveraines Autonomes' : 'Autonomous Sovereign Observations'}
        </h2>
        <p className="iosa-block-text">
          {lang === 'fr'
            ? "Ces observations documentent des déltas mesurables — des écarts entre ce qu'un État déclare et ce que les données primaires révèlent. Chaque observation repose sur une source unique, auditée et reproductible. Elles ne produisent ni classement, ni jugement, ni causalité. Elles mettent en évidence des réalités objectivables dont l'analyse peut conduire à des décisions souveraines."
            : "These observations document measurable deltas — gaps between what a state declares and what primary data reveals. Each observation relies on a single, audited and reproducible source. They produce no ranking, judgment, or causal claim. They highlight objective realities whose analysis can lead to sovereign decisions."}
        </p>
      </div>

      {!hasData ? (
        <p className="iosa-detail-empty">
          {lang === 'fr' ? 'Aucune observation disponible pour ce pays.' : 'No observations available for this country.'}
        </p>
      ) : (
        <>
          {/* Vue synthétique */}
          {!selected && (
            <div className="iosa-block">
              <h2 className="iosa-block-title">
                {lang === 'fr' ? 'Observations disponibles' : 'Available observations'}
              </h2>
              <table className="iosa-obs-table">
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
                    const cfg = INDICATOR_CONFIG[code]?.[lang]
                    const pubInCov = PUB_YEARS.filter(y => isInCoverage(y, code))
                    const status = getObsStatus(rows, pubInCov)
                    const tendency = getTendency(rows, pubInCov, code)
                    const arrow = tendency === 'up' ? '↗' : tendency === 'down' ? '↘' : '→'
                    const arrowColor = tendency === 'up'
                      ? '#B00020'
                      : tendency === 'down' ? 'var(--color-primary)' : 'var(--color-muted)'
                    return (
                      <tr key={code}>
                        <td>
                          <span className="iosa-obs-name">{cfg?.label || code}</span>
                          <span className="iosa-obs-pillar">{rows[0]?.pillar_code}</span>
                        </td>
                        <td>
                          <span className="iosa-obs-delta">{cfg?.metric_label}</span>
                        </td>
                        <td><StatusBadge status={status} lang={lang} /></td>
                        <td style={{ fontSize: '1.3rem', textAlign: 'center', color: arrowColor }}>
                          {arrow}
                        </td>
                        <td>
                          <button className="iosa-btn-voir" onClick={() => setSelected(code)}>
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
              <button className="iosa-back-top" onClick={() => setSelected(null)}>
                ← {lang === 'fr' ? 'Toutes les observations' : 'All observations'}
              </button>
              <IndicatorDetail
                code={selected}
                rows={byIndicator[selected] || []}
                lang={lang}
                iso3={iso3}
              />
            </>
          )}
        </>
      )}

      <p className="iosa-disclaimer">
        {lang === 'fr'
          ? "Les observations souveraines autonomes ne constituent pas un jugement sur la gouvernance des États. Elles documentent des phénomènes objectivables dont l'analyse et les décisions relèvent de la responsabilité souveraine des États, des chercheurs et des institutions."
          : "Autonomous sovereign observations do not constitute a judgment on state governance. They document objective phenomena whose analysis and decisions are the sovereign responsibility of states, researchers, and institutions."}
      </p>
    </div>
  )
}
