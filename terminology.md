# OSA/ISA — Charte terminologique API
*Document de référence interne — à appliquer lors de la Phase 1 de normalisation Swagger*

---

## Objet

Ce document fixe le vocabulaire officiel de l'API publique OSA/ISA.
Il s'applique aux `summary`, `description`, `Field(description=...)` Pydantic,
noms de champs JSON publics, noms d'endpoints, et tags Swagger.

Il ne s'applique **pas** aux noms internes SQL (vues, colonnes `ma.*`),
ni aux noms de variables Python internes — sauf lors d'un refactor explicite (Phase 3).

---

## 1. Lexique de substitution

### 1.1 Vocabulaire général

| À éviter (dev/ML) | Préférer (institutionnel/ISA) | Justification |
|---|---|---|
| `fragility` | `resilience` ou `structural exposure` | Connotation défavorable, éviter dans contexte diplomatique |
| `weak_state` / `weak` | `institutional_capacity` | Neutre, analytique |
| `failed_state` / `failed` | `sovereign_stress` | Non-qualifiant |
| `unstable` | `structurally exposed` | Mesurable, pas normatif |
| `poor` (adjectif) | `limited` ou `low` | Connotation évitable |
| `prediction` / `predicted` | `prospective assessment` ou `predictive intelligence` | Distingue signal analytique de certitude |
| `forecast` (brut) | `prospective scenario` | Idem |
| `threat` (exposé) | `exposure` | Moins guerrier, plus analytique |
| `risk` (exposé) | `vulnerability` | Cohérent avec terminologie OCDE/UA |
| `score_ml` / `ml_score` | `predictive_score` | Masque l'implémentation |
| `simulation_ready` | `operational_readiness` | Vocabulaire institutionnel |
| `corruption` | `governance maturity` ou `accountability index` | Éviter qualification directe |
| `threat_level` | `alert_level` ou `risk_level` | Neutre |
| `atrocity` (exposé publiquement) | `civilian protection risk` | Contextualise sans qualifier |
| `genocide` (exposé) | ❌ ne jamais exposer dans l'API publique | Qualification juridique réservée |
| `conflict economy` (brut) | `conflict-enabling conditions` | Plus précis, moins accusateur |

### 1.2 Scores et métriques

| Interne | Public API | Notes |
|---|---|---|
| `atrocity_precursor_score` | `civilian_protection_risk_score` | Dans la couche `mg.*` uniquement |
| `geneco_exposure_score` | `conflict_economy_exposure_score` | Acceptable tel quel si accompagné de `methodology_note` |
| `early_warning_score` | `sovereign_risk_score` | Déjà cohérent |
| `fragility_warning_score` | `structural_vulnerability_score` | |
| `stress_propagation_score` | `systemic_stress_score` | |
| `isa_trend_slope` | `sovereignty_trend` | Simplifié pour lecture externe |
| `isa_volatility` | `sovereignty_volatility` | |
| `observation_confidence` | `data_confidence` | Plus clair pour utilisateur externe |

### 1.3 Niveaux d'alerte (bandes de risque)

Les bandes couleur sont conservées telles quelles (GREEN / YELLOW / ORANGE / RED / BLACK) — elles sont déjà une convention ISA lisible. Ajouter systématiquement un `risk_label` textuel en parallèle.

| Bande | `risk_label` public recommandé |
|---|---|
| GREEN | `Low monitored exposure` |
| YELLOW | `Watchlist exposure` |
| ORANGE | `Elevated structural exposure` |
| RED | `Critical prevention priority` |
| BLACK | `Urgent sovereign review required` |
| LOW_CONFIDENCE | `Contextual assessment — expert review required` |

---

## 2. Noms d'endpoints

### 2.1 Règles générales

- `snake_case` stable, préférer les noms **substantifs** plutôt que verbaux
- Pas de version dans le path avant stabilisation V10 (`/v2/` réservé à Phase 3)
- Pas de sigles ML dans le path public

### 2.2 Exemples

| Actuel / dev | Standard ISA recommandé |
|---|---|
| `/ml_predictions` | `/predictive-intelligence` |
| `/p7z/readiness` | `/p7z/sovereign-readiness` |
| `/early_warning` | `/early-warning` (tiret, pas underscore dans paths) |
| `/p7i/amar` | `/p7i/civilian-protection` |
| `/p7i/geneco` | `/p7i/conflict-economy-exposure` |
| `/isa_score` | `/isa/sovereign-index` |

---

## 3. Tags Swagger

| À éviter | Standard ISA |
|---|---|
| `ML` | `Predictive Intelligence` |
| `debug` | ❌ ne jamais exposer en prod |
| `test` | ❌ ne jamais exposer en prod |
| `P7I raw` | `Early Warning & Risk Intelligence` |
| `AMAR` | `Civilian Protection Risk` |
| `GENECO` | `Conflict Economy Exposure` |
| `ISA` | `Sovereign Index (ISA)` |
| `P7Z` | `Sovereign Readiness (P7Z)` |

---

## 4. Standards de rédaction des `description=`

### Style cible : institutionnel analytique

Modèle OCDE/Banque mondiale — sobre, précis, non prescriptif.

**Structure recommandée pour une `description` d'endpoint :**
```
[Verbe neutre] [objet analytique] [périmètre géographique/temporel].
Inclut [liste des métriques clés].
[Limite méthodologique si pertinente, en une phrase.]
```

**Exemple conforme :**
```
Provides aggregated sovereign resilience indicators by country and year,
covering structural exposure, conflict escalation dynamics, and governance capacity.
Includes predictive scores, confidence levels, and alert classifications.
This is an early-warning signal. It does not constitute a legal qualification.
```

**Mentions obligatoires pour AMAR et GENECO :**
Toute description d'endpoint exposant des scores AMAR ou GENECO doit inclure :
> *"This indicator provides an early-warning signal for prevention purposes.
> It does not constitute a legal qualification of atrocity, genocide,
> or criminal responsibility."*

---

## 5. Champs jamais exposés publiquement

Les champs suivants ne doivent pas apparaître dans les schémas Pydantic publics (`mg.*` layer),
même s'ils existent dans les vues `ma.*` internes :

- `forecast_blocking_reason`
- `swot_data_status`
- `strategic_diagnostic_role` (exposer `strategic_attention_class` à la place)
- `stress_simulation_confidence` (exposer uniquement `data_confidence`)
- `central_isa_delta` / `ambitious_isa_delta` / `stress_isa_delta` (noms de scénario internes)
- Toute colonne prefixée `_debug`, `_raw`, `_internal`

---

## 6. Plan d'application

| Phase | Périmètre | Risque | Quand |
|---|---|---|---|
| **Phase 1** — Documentation | `summary`, `description`, `Field(description=...)` | Zéro | Sprint précédant la première démo externe |
| **Phase 2** — Alias publics | Pydantic `alias=` sur champs exposés | Faible | Après stabilisation AMAR/GENECO en prod |
| **Phase 3** — Refactor complet | Renommage JSON, endpoints, nettoyage ML legacy | Moyen | Lors du passage à V10 stabilisée, avec versioning `/v2/` |

---

## 7. Principe directeur

> L'API OSA/ISA est un instrument analytique souverain, pas un moteur de scoring académique.
> Chaque mot exposé publiquement est potentiellement lu par un décideur institutionnel,
> un partenaire diplomatique, ou un journaliste.
> La précision terminologique est une forme de crédibilité.

---

*Créé : Sprint 5 — à mettre à jour avant chaque Phase de normalisation.*
