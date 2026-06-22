// Generation automatisee du texte Conflict Economy (GENECO) -- regles deterministes.
// Reutilise la classification de tendance/confiance d'amarContent.js (memes seuils).
// Voir docs/amar-automation.md pour la documentation du principe general.

import { classifyVariation, classifyConfidence } from './amarContent'

export { classifyVariation, classifyConfidence }

// Facteurs generaux suivis par GENECO (description conceptuelle -- la vue publique
// persistee ne detaille pas les sous-dimensions chiffrees, cf. docs/amar-automation.md).
export const GENECO_FACTORS = {
  en: ['Resource capture', 'Logistics enabling', 'Institutional capture', 'Civilian exploitation', 'Narrative weaponization'],
  fr: ['Captation de ressources', 'Facilitation logistique', 'Captation institutionnelle', 'Exploitation civile', 'Instrumentalisation narrative']
}

const BAND_LABEL_TEXT = {
  fr: { GREEN: 'Faible', YELLOW: 'Surveillance', ORANGE: 'Élevé', RED: 'Critique', BLACK: 'Critique maximal' },
  en: { GREEN: 'Low', YELLOW: 'Watchlist', ORANGE: 'Elevated', RED: 'Critical', BLACK: 'maximum Critical' }
}

const BAND_CONTEXT = {
  GREEN: {
    fr: "Aucune exposition significative aux dynamiques de captation de ressources susceptibles d'alimenter une économie de conflit n'est identifiée à ce stade.",
    en: "No significant exposure to resource-capture dynamics likely to fuel a conflict economy is identified at this stage."
  },
  YELLOW: {
    fr: "Aucun élément ne permet de caractériser une exposition majeure à ce stade, mais plusieurs dimensions méritent une observation continue.",
    en: "No element characterizes major exposure at this stage, but several dimensions warrant continued observation."
  },
  ORANGE: {
    fr: "Cette classification appelle un suivi renforcé des dynamiques de captation de ressources et de logistique, sans constituer à ce stade une qualification de crise avérée.",
    en: "This classification calls for reinforced monitoring of resource-capture and logistics dynamics, without constituting a confirmed crisis qualification at this stage."
  },
  RED: {
    fr: "Cette classification justifie une attention immédiate, sans constituer une attribution de responsabilité ni une qualification de génocide.",
    en: "This classification warrants immediate attention, without constituting an attribution of responsibility or a genocide determination."
  },
  BLACK: {
    fr: "Cette classification justifie une attention immédiate et soutenue, sans constituer une attribution de responsabilité ni une qualification de génocide.",
    en: "This classification warrants immediate and sustained attention, without constituting an attribution of responsibility or a genocide determination."
  }
}

const TREND_CLAUSE = {
  STABLE: {
    fr: (pct) => `Le score d'exposition est resté stable sur la période récente (variation de ${pct}).`,
    en: (pct) => `The exposure score has remained stable over the recent period (variation of ${pct}).`
  },
  MODERATE_INCREASE: {
    fr: (pct) => `Le score d'exposition a connu une hausse modérée sur la période récente (${pct}), suggérant une légère intensification des dimensions suivies.`,
    en: (pct) => `The exposure score has seen a moderate increase over the recent period (${pct}), suggesting a slight intensification of the tracked dimensions.`
  },
  STRONG_INCREASE: {
    fr: (pct) => `Le score d'exposition a connu une hausse marquée sur la période récente (${pct}), indiquant une intensification notable des dimensions suivies.`,
    en: (pct) => `The exposure score has seen a marked increase over the recent period (${pct}), indicating a notable intensification of the tracked dimensions.`
  },
  MODERATE_DECREASE: {
    fr: (pct) => `Le score d'exposition a connu une baisse modérée sur la période récente (${pct}), suggérant un léger relâchement des dimensions suivies.`,
    en: (pct) => `The exposure score has seen a moderate decrease over the recent period (${pct}), suggesting a slight easing of the tracked dimensions.`
  },
  STRONG_DECREASE: {
    fr: (pct) => `Le score d'exposition a connu une baisse marquée sur la période récente (${pct}), indiquant un relâchement notable des dimensions suivies.`,
    en: (pct) => `The exposure score has seen a marked decrease over the recent period (${pct}), indicating a notable easing of the tracked dimensions.`
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
    fr: (conf) => `Le niveau de confiance associé à cette évaluation reste limité (${conf}), ce qui appelle une prudence particulière dans l'interprétation des dimensions.`,
    en: (conf) => `The confidence level associated with this assessment remains limited (${conf}), calling for particular caution in interpreting the dimensions.`
  }
}

export function generateGenecoSummary({ year, country, band, variationPct, confidenceScore, lang }) {
  const label = BAND_LABEL_TEXT[lang][band] || band
  const trendKey = classifyVariation(variationPct)
  const confKey = classifyConfidence(confidenceScore)
  const pctStr = `${variationPct >= 0 ? '+' : ''}${variationPct.toFixed(1)}%`
  const confStr = `${Math.round(confidenceScore * 100)}%`

  const opening = lang === 'fr'
    ? `L'évaluation Conflict Economy ${year} classe ${country} au niveau ${label}.`
    : `The ${year} Conflict Economy assessment places ${country} at the ${label} level.`

  return [
    opening,
    BAND_CONTEXT[band]?.[lang] || '',
    TREND_CLAUSE[trendKey][lang](pctStr),
    CONFIDENCE_CLAUSE[confKey][lang](confStr)
  ].filter(Boolean).join(' ')
}

const RESILIENCE_BASE = {
  GREEN: {
    fr: { resilience: "Aucun signal d'exposition significatif. Cadre institutionnel et économique apparemment robuste face aux dynamiques de captation.", vulnerability: "Aucune vulnérabilité majeure identifiée à ce stade. Suivi de routine maintenu." },
    en: { resilience: "No significant exposure signal. Institutional and economic framework appears robust against capture dynamics.", vulnerability: "No major vulnerability identified at this stage. Routine monitoring maintained." }
  },
  YELLOW: {
    fr: { resilience: "Aucun signal critique observé sur l'ensemble des dimensions suivies.", vulnerability: "Présence de signaux persistants sur certaines dimensions, nécessitant un suivi régulier." },
    en: { resilience: "No critical signal observed across the tracked dimensions.", vulnerability: "Persistent signals on certain dimensions, requiring regular monitoring." }
  },
  ORANGE: {
    fr: { resilience: "Capacités institutionnelles existantes pouvant être mobilisées pour limiter la captation de ressources.", vulnerability: "Convergence de plusieurs dimensions suggérant une exposition croissante aux dynamiques d'économie de conflit." },
    en: { resilience: "Existing institutional capacities that could be mobilized to limit resource capture.", vulnerability: "Convergence of several dimensions suggesting growing exposure to conflict-economy dynamics." }
  },
  RED: {
    fr: { resilience: "Marge de manœuvre réduite ; toute action de limitation nécessite une mobilisation rapide.", vulnerability: "Convergence significative des dimensions de risque. Exposition élevée aux dynamiques de captation et d'exploitation." },
    en: { resilience: "Reduced room for maneuver; any mitigation action requires rapid mobilization.", vulnerability: "Significant convergence of risk dimensions. High exposure to capture and exploitation dynamics." }
  },
  BLACK: {
    fr: { resilience: "Marge de manœuvre très réduite ; une mobilisation immédiate est nécessaire.", vulnerability: "Convergence sévère et persistante des dimensions de risque. Exposition critique aux dynamiques d'économie de conflit." },
    en: { resilience: "Very limited room for maneuver; immediate mobilization is needed.", vulnerability: "Severe and persistent convergence of risk dimensions. Critical exposure to conflict-economy dynamics." }
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

export function generateGenecoResilience({ band, variationPct, lang }) {
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
