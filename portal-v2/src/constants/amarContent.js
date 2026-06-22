// Generation automatisee du texte AMAR (regles deterministes, sans IA generative)
// Voir docs/amar-automation.md pour la documentation complete des regles.

// Facteurs generaux suivis par AMAR (description conceptuelle -- la vue publique
// persistee ne detaille pas les sous-dimensions chiffrees, contrairement au
// moteur live qui est trop lent pour une consultation interactive, cf.
// docs/amar-automation.md).
export const AMAR_FACTORS = {
  en: ['Civilian protection', 'Security pressures', 'Social tensions', 'Institutional fragility'],
  fr: ['Protection civile', 'Pressions sécuritaires', 'Tensions sociales', 'Fragilités institutionnelles']
}

const BAND_LABEL_TEXT = {
  fr: { GREEN: 'Faible', YELLOW: 'Surveillance', ORANGE: 'Élevé', RED: 'Critique', BLACK: 'Critique maximal' },
  en: { GREEN: 'Low', YELLOW: 'Watchlist', ORANGE: 'Elevated', RED: 'Critical', BLACK: 'maximum Critical' }
}

const BAND_CONTEXT = {
  GREEN: {
    fr: "Aucun facteur de préoccupation immédiate n'est identifié pour la protection des populations civiles.",
    en: "No factor of immediate concern is identified for civilian protection."
  },
  YELLOW: {
    fr: "Aucun élément ne permet de caractériser une situation de crise majeure à ce stade, mais plusieurs indicateurs méritent une attention régulière.",
    en: "No element characterizes a major crisis situation at this stage, but several indicators warrant regular attention."
  },
  ORANGE: {
    fr: "Cette classification appelle une vigilance renforcée, sans constituer à ce stade une qualification de crise avérée.",
    en: "This classification calls for reinforced vigilance, without constituting a confirmed crisis qualification at this stage."
  },
  RED: {
    fr: "Cette classification justifie une attention immédiate, sans constituer une qualification juridique ou une alerte opérationnelle formelle.",
    en: "This classification warrants immediate attention, without constituting a legal qualification or a formal operational alert."
  },
  BLACK: {
    fr: "Cette classification justifie une attention immédiate et soutenue, sans constituer une qualification juridique ou une alerte opérationnelle formelle.",
    en: "This classification warrants immediate and sustained attention, without constituting a legal qualification or a formal operational alert."
  }
}

const TREND_CLAUSE = {
  STABLE: {
    fr: (pct) => `Le score est resté stable sur la période récente (variation de ${pct}).`,
    en: (pct) => `The score has remained stable over the recent period (variation of ${pct}).`
  },
  MODERATE_INCREASE: {
    fr: (pct) => `Le score a connu une hausse modérée sur la période récente (${pct}), suggérant une légère intensification des signaux suivis.`,
    en: (pct) => `The score has seen a moderate increase over the recent period (${pct}), suggesting a slight intensification of the tracked signals.`
  },
  STRONG_INCREASE: {
    fr: (pct) => `Le score a connu une hausse marquée sur la période récente (${pct}), indiquant une intensification notable des signaux suivis.`,
    en: (pct) => `The score has seen a marked increase over the recent period (${pct}), indicating a notable intensification of the tracked signals.`
  },
  MODERATE_DECREASE: {
    fr: (pct) => `Le score a connu une baisse modérée sur la période récente (${pct}), suggérant un léger relâchement des signaux suivis.`,
    en: (pct) => `The score has seen a moderate decrease over the recent period (${pct}), suggesting a slight easing of the tracked signals.`
  },
  STRONG_DECREASE: {
    fr: (pct) => `Le score a connu une baisse marquée sur la période récente (${pct}), indiquant un relâchement notable des signaux suivis.`,
    en: (pct) => `The score has seen a marked decrease over the recent period (${pct}), indicating a notable easing of the tracked signals.`
  }
}

const CONFIDENCE_CLAUSE = {
  HIGH: {
    fr: (conf) => `Le niveau de confiance associé à cette évaluation est élevé (${conf}).`,
    en: (conf) => `The confidence level associated with this assessment is high (${conf}).`
  },
  MODERATE: {
    fr: (conf) => `Le niveau de confiance associé à cette évaluation est modéré (${conf}), invitant à une lecture prudente.`,
    en: (conf) => `The confidence level associated with this assessment is moderate (${conf}), warranting a cautious reading.`
  },
  LOW: {
    fr: (conf) => `Le niveau de confiance associé à cette évaluation reste limité (${conf}), ce qui appelle une prudence particulière dans l'interprétation des signaux.`,
    en: (conf) => `The confidence level associated with this assessment remains limited (${conf}), calling for particular caution in interpreting the signals.`
  }
}

export function classifyVariation(pct) {
  if (Math.abs(pct) < 5) return 'STABLE'
  if (pct >= 15) return 'STRONG_INCREASE'
  if (pct >= 5) return 'MODERATE_INCREASE'
  if (pct <= -15) return 'STRONG_DECREASE'
  return 'MODERATE_DECREASE'
}

export function classifyConfidence(score) {
  if (score >= 0.75) return 'HIGH'
  if (score >= 0.5) return 'MODERATE'
  return 'LOW'
}

// Genere le resume analytique (Bloc 2) par composition de fragments deterministes.
// Aucune IA generative -- chaque fragment est selectionne par une regle explicite
// a partir de variables reelles (band, variation, confiance). Voir docs/amar-automation.md.
export function generateAmarSummary({ year, country, band, variationPct, confidenceScore, lang }) {
  const label = BAND_LABEL_TEXT[lang][band] || band
  const trendKey = classifyVariation(variationPct)
  const confKey = classifyConfidence(confidenceScore)
  const pctStr = `${variationPct >= 0 ? '+' : ''}${variationPct.toFixed(1)}%`
  const confStr = `${Math.round(confidenceScore * 100)}%`

  const opening = lang === 'fr'
    ? `L'évaluation AMAR ${year} classe ${country} au niveau ${label}.`
    : `The ${year} AMAR assessment places ${country} at the ${label} level.`

  return [
    opening,
    BAND_CONTEXT[band]?.[lang] || '',
    TREND_CLAUSE[trendKey][lang](pctStr),
    CONFIDENCE_CLAUSE[confKey][lang](confStr)
  ].filter(Boolean).join(' ')
}

const RESILIENCE_BASE = {
  GREEN: {
    fr: { resilience: "Absence de signal de risque significatif. Cadre de gouvernance et de protection civile apparemment stable.", vulnerability: "Aucune vulnérabilité majeure identifiée à ce stade. Suivi de routine maintenu." },
    en: { resilience: "No significant risk signal. Governance and civilian protection framework appears stable.", vulnerability: "No major vulnerability identified at this stage. Routine monitoring maintained." }
  },
  YELLOW: {
    fr: { resilience: "Absence de signal critique observé.", vulnerability: "Présence de signaux persistants nécessitant un suivi régulier." },
    en: { resilience: "No critical signal observed.", vulnerability: "Persistent signals requiring regular monitoring." }
  },
  ORANGE: {
    fr: { resilience: "Capacités institutionnelles existantes pouvant être mobilisées pour une réponse préventive.", vulnerability: "Convergence de plusieurs signaux suggérant une exposition croissante. Fragilités nécessitant un suivi rapproché." },
    en: { resilience: "Existing institutional capacities that could be mobilized for a preventive response.", vulnerability: "Convergence of several signals suggesting growing exposure. Fragilities requiring close monitoring." }
  },
  RED: {
    fr: { resilience: "Marge de manœuvre réduite ; toute action préventive nécessite une mobilisation rapide.", vulnerability: "Convergence significative de signaux de risque. Fragilités institutionnelles et sociales nécessitant une attention immédiate." },
    en: { resilience: "Reduced room for maneuver; any preventive action requires rapid mobilization.", vulnerability: "Significant convergence of risk signals. Institutional and social fragilities requiring immediate attention." }
  },
  BLACK: {
    fr: { resilience: "Marge de manœuvre très réduite ; une mobilisation immédiate des capacités disponibles est nécessaire.", vulnerability: "Convergence sévère et persistante de signaux de risque. Fragilités institutionnelles et sociales critiques." },
    en: { resilience: "Very limited room for maneuver; immediate mobilization of available capacities is needed.", vulnerability: "Severe and persistent convergence of risk signals. Critical institutional and social fragilities." }
  }
}

const TREND_VULNERABILITY_SUFFIX = {
  STRONG_INCREASE: { fr: " La trajectoire récente accentue ce facteur de vulnérabilité.", en: " The recent trajectory reinforces this vulnerability factor." },
  MODERATE_INCREASE: { fr: " La trajectoire récente accentue légèrement ce facteur de vulnérabilité.", en: " The recent trajectory slightly reinforces this vulnerability factor." }
}

const TREND_RESILIENCE_SUFFIX = {
  STRONG_DECREASE: { fr: " La trajectoire récente renforce ce facteur de résilience.", en: " The recent trajectory reinforces this resilience factor." },
  MODERATE_DECREASE: { fr: " La trajectoire récente renforce légèrement ce facteur de résilience.", en: " The recent trajectory slightly reinforces this resilience factor." }
}

// Genere le bloc resilience/vulnerabilite (Bloc 5) -- base par niveau, nuance par tendance.
export function generateAmarResilience({ band, variationPct, lang }) {
  const base = RESILIENCE_BASE[band]?.[lang]
  if (!base) return null
  const trendKey = classifyVariation(variationPct)
  const vulnSuffix = TREND_VULNERABILITY_SUFFIX[trendKey]?.[lang] || ''
  const resSuffix = TREND_RESILIENCE_SUFFIX[trendKey]?.[lang] || ''
  return {
    resilience: base.resilience + resSuffix,
    vulnerability: base.vulnerability + vulnSuffix
  }
}
