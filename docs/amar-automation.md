# Automatisation de la génération des rapports AMAR et Conflict Economy (GENECO)

## Principe

Le contenu textuel des rapports publics AMAR (`/country/{iso3}/amar`) et Conflict Economy (`/country/{iso3}/conflict-economy`) n'est pas rédigé manuellement pays par pays. Il est généré automatiquement par un moteur de règles déterministe, à partir de variables réelles issues de l'API.

Aucune intelligence artificielle générative n'est utilisée. Chaque phrase produite est sélectionnée par une règle explicite, reproductible et auditable — cohérent avec la doctrine P7E (observation pure, jamais de génération non vérifiable).

Les deux rapports suivent exactement le même principe de génération, avec des fragments de texte propres à chaque domaine (protection civile pour AMAR, exposition économique pour GENECO).

## Périmètre temporel : 2020-2024, par doctrine — pas par limitation technique

**C'est le point le plus important de cette documentation.** AMAR et GENECO sont publiés sur la période 2020-2024, et ce périmètre n'est ni arbitraire ni un défaut à corriger. Il reflète une réalité méthodologique vérifiée :

- Les indicateurs SWOT (codes `WKN_`, `THR_`, `STR_`, `OPP_`), intrants du moteur AMAR/GENECO, sont stockés dans les tables partitionnées `computed_values_YYYY`. Ces partitions **n'existent pas avant 2020** (`computed_values_2015` par exemple n'existe tout simplement pas en base).
- Le moteur produit techniquement un score pour 2010-2019 (via une jointure externe qui tolère l'absence de signal SWOT), mais ce score repose alors sur un sous-ensemble d'intrants méthodologiques plus restreint que 2020-2024.
- Ceci est cohérent avec la politique de publication OSA déjà en place (`rf.publication_policy`), qui traite 2020 comme le début du statut OFFICIAL pour l'ensemble de la plateforme — pas seulement pour AMAR/GENECO.

Les endpoints publics (`/opendata/alerts/amar/{iso3}` et `/opendata/alerts/geneco/{iso3}`) appliquent un filtre explicite `year >= 2020`, documenté dans leur docstring respectif. Ce filtre était déjà en place pour AMAR avant ce chantier ; il a été répliqué à l'identique pour GENECO.

**Mésaventure du 21 juin 2026, à ne pas reproduire** : en cherchant à enrichir l'historique de Conflict Economy (qui semblait limité à une seule année à cause d'un bug d'endpoint distinct, voir plus bas), les deux pages ont été temporairement basculées vers les vues moteur live (`ma.v_p7i_amar_dashboard`, `ma.v_p7i_amar_geneco_dashboard`) plutôt que les vues publiques persistées. Ces vues moteur exposent bien 15 ans de données (2010-2024) avec des sous-dimensions chiffrées détaillées, mais elles recalculent en direct l'ensemble du moteur sémantique et de simulation à chaque requête — observées entre 48 et 112 secondes par pays via `EXPLAIN ANALYZE`, avec des tris débordant sur disque. Inutilisable en production. Retour aux vues persistées, qui répondent en quelques dizaines de millisecondes.

## Sources de données

| Indicateur | Endpoint public | Vue source | Période |
|---|---|---|---|
| AMAR (civilian protection) | `/opendata/alerts/amar/{iso3}` | `mg.v_public_p7i_amar_alerts` (persistée) | 2020–2024 |
| Conflict Economy (GENECO) | `/opendata/alerts/geneco/{iso3}` | `mg.v_public_p7i_amar_geneco_alerts` (persistée) | 2020–2024 |

L'endpoint GENECO par pays n'existait pas avant ce chantier — il a été créé dans `api/routers/opendata.py` en miroir exact de l'endpoint AMAR existant (même structure, même filtre `year >= 2020`, même vue persistée mais pour GENECO).

**À éviter absolument** : les routes `/api/v2/early-warning/civilian-protection/{iso3}` et `/api/v2/early-warning/conflict-economy/{iso3}` (fichier `api/routers/early_warning.py`). Ce sont les vues moteur live décrites ci-dessus — réservées à un usage interne/batch, jamais à une consultation interactive.

## Variables d'entrée

| Variable | Usage |
|---|---|
| `risk_band` | année la plus récente — sélectionne le contexte par niveau |
| `risk_score` | comparé entre première et dernière année disponible — calcule la variation en % |
| `confidence_score` | année la plus récente — sélectionne la clause de confiance |

Les vues persistées ne contiennent pas de sous-dimensions chiffrées (pas de `structural_fragility_score`, `resource_capture_risk`, etc.) — seules les vues moteur live les exposent, et celles-ci sont trop lentes pour une consultation directe. Le bloc « Facteurs suivis » affiche donc une liste descriptive des dimensions conceptuellement couvertes, sans prétendre à des valeurs chiffrées qu'on ne peut pas étayer (principe « pas d'approximation »).

## Classifications dérivées

### Tendance — `classifyVariation(pct)`

| Seuil | Catégorie |
|---|---|
| \|variation\| < 5 % | `STABLE` |
| variation ≥ 15 % | `STRONG_INCREASE` |
| 5 % ≤ variation < 15 % | `MODERATE_INCREASE` |
| variation ≤ -15 % | `STRONG_DECREASE` |
| -15 % < variation ≤ -5 % | `MODERATE_DECREASE` |

### Confiance — `classifyConfidence(score)`

| Seuil | Catégorie |
|---|---|
| confidence ≥ 0.75 | `HIGH` |
| 0.5 ≤ confidence < 0.75 | `MODERATE` |
| confidence < 0.5 | `LOW` |

Ces deux fonctions sont définies une seule fois dans `amarContent.js` et réutilisées par `genecoContent.js` (import direct, pas de duplication).

## Composition du texte par bloc

### Bloc « Résumé analytique » (`generateAmarSummary` / `generateGenecoSummary`)

Concaténation de 4 fragments :
1. Phrase d'ouverture — niveau + pays + année (calculée, jamais fixe)
2. Contexte par niveau — 5 variantes (une par bande : GREEN/YELLOW/ORANGE/RED/BLACK)
3. Clause de tendance — 5 variantes (une par catégorie de variation)
4. Clause de confiance — 3 variantes (une par catégorie de confiance)

→ **5 × 5 × 3 = 75 combinaisons possibles** par indicateur.

### Bloc « Trajectoire » (`readingText`)

Utilise `classifyVariation` pour choisir entre 3 lectures : stable / dégradation / amélioration, sur l'intégralité de la période disponible (2020-2024).

### Bloc « Résilience et vulnérabilité » (`generateAmarResilience` / `generateGenecoResilience`)

Texte de base par niveau (5 variantes), nuancé par un suffixe conditionnel quand la tendance est marquée :
- Hausse forte ou modérée du score → suffixe ajouté au texte de vulnérabilité.
- Baisse forte ou modérée du score → suffixe ajouté au texte de résilience.
- Tendance stable → pas de suffixe.

## Emplacement du code

- `api/routers/opendata.py` — endpoints `/alerts/amar/{iso3}` et `/alerts/geneco/{iso3}` (vues persistées, `year >= 2020`)
- `portal-v2/src/api/alerts.js` — appels aux deux endpoints `/opendata/alerts/...`
- `portal-v2/src/constants/amarContent.js` — fragments AMAR, fonctions de classification (`classifyVariation`, `classifyConfidence`), génération AMAR
- `portal-v2/src/constants/genecoContent.js` — fragments GENECO, génération GENECO (réutilise la classification d'`amarContent.js`)
- `portal-v2/src/pages/AmarDetail.jsx` — page AMAR
- `portal-v2/src/pages/ConflictEconomyDetail.jsx` — page GENECO (même structure, réutilise `AmarDetail.css`)
- `portal-v2/src/components/ScoreTable/ScoreTable.jsx` — lignes AMAR et Conflict economy du tableau pays, historique complet disponible par année

## Limites assumées

- Les fragments eux-mêmes restent rédigés et validés manuellement par OSA — seules leur **sélection** et leur **combinaison** sont automatisées.
- Les seuils de classification (5 %, 15 %, 0.5, 0.75) sont des valeurs de départ raisonnables mais arbitraires — à ajuster si l'observation empirique sur les 54 pays montre qu'ils ne discriminent pas correctement les situations.
- `ConflictEconomyDetail.jsx` réutilise les classes CSS d'`AmarDetail.css` plutôt qu'une feuille de style dédiée, pour éviter la duplication entre deux pages structurellement identiques.
- Si une vue matérialisée dédiée (sur le modèle de `pub.mv_trajectories`, rafraîchie périodiquement) est construite un jour pour exposer les sous-dimensions chiffrées sans le coût de calcul live, le bloc « Facteurs suivis » pourra repasser à un affichage chiffré par dimension. Ce n'est pas un correctif à faire en urgence sur la vue moteur existante.

## Historique

- v1 (20 juin 2026) : génération combinatoire AMAR uniquement, historique 2020-2024 via `mg.v_public_p7i_amar_alerts`.
- v2 (21 juin 2026, abandonnée) : tentative d'extension à 15 ans (2010-2024) et de sous-dimensions chiffrées via les vues moteur `ma.v_p7i_amar_dashboard` / `ma.v_p7i_amar_geneco_dashboard`. Revertée le jour même : temps de réponse de 48 à 112 secondes par pays en production, et le SWOT (intrant du moteur) n'a structurellement aucune donnée avant 2020, ce qui invalidait de toute façon l'intérêt de l'historique étendu.
- v3 (21 juin 2026) : extension à GENECO sur le modèle exact d'AMAR — création de l'endpoint `/opendata/alerts/geneco/{iso3}` (inexistant jusque-là), retour aux vues persistées pour les deux indicateurs, confirmation du périmètre 2020-2024 comme choix doctrinal documenté plutôt que limitation technique.
