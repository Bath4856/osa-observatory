# OSA / ISA — P8 V2 FOUNDATION V2

## Institutional Public Observatory — Publication Layer

Version: P8V2_CORRECTED  
Status: ACTIVE_CANDIDATE  
Scope: Publication Layer — couche de publication institutionnelle publique  
Dependencies:
- P7J v2 (ma.v_isa_decision_country_year)
- P7K V3 FROZEN (ma.mv_isa_executive_master_board)
- P7Z Phase 2 (ma.mv_isa_p7z_execution_probability, ma.v_isa_p7z_fragility_engine)
- mg.fn_check_matview, mg.fn_check_view (patch_mg_check_helpers.sql)

---

# 1. Purpose

P8 V2 est la couche de publication institutionnelle d'OSA/ISA.

Il expose les résultats analytiques de la chaîne P7A–P7Z via un schéma `pub` structuré, un registre de datasets et un contrat d'API versionnée.

P8 V2 ne calcule pas — il publie ce que les couches analytiques ont produit :
- scores ISA observés (P7A–P7E)
- décisions souveraines (P7J v2)
- conditions d'exécution (P7K V3 FROZEN)
- probabilités et fragilité souveraine (P7Z Phase 2)

P8 V2 ne remplace pas P8OPS immédiatement. Les deux coexistent en parallèle jusqu'à validation complète.

---

# 2. Corrections vs V1

| Problème V1 | Correction V2 |
|-------------|---------------|
| Ligne SQL orpheline `file.',NOW()),` | Supprimée — INSERT syntaxiquement correct |
| Aucune vue `pub.*` créée | 10 vues créées dans le schéma `pub` |
| P7Z Phase 2 absent | 3 datasets + 4 endpoints P7Z intégrés |
| Pré-check incomplet | Vérifie P7K FROZEN + P7Z ACTIVE + toutes MV |

---

# 3. Architecture pub.*

```text
pub.v_isa_country_latest          — scores ISA dernière année + P7J + P7Z
pub.v_isa_country_history         — historique 2010–2024 + P7J
pub.v_isa_country_rankings        — classements ISA par année
pub.v_isa_pillar_breakdown        — scores piliers + P7Z convergence
pub.v_isa_opportunity_catalog     — catalogue interventions + P7Z probability
pub.v_isa_release_manifest        — manifest release avec compteurs
pub.v_isa_public_methodology      — méthodologie et packages actifs
pub.v_isa_p7z_country_readiness   — readiness prédictive P7Z par pays (NEW)
pub.v_isa_p7z_execution_signals   — signaux d'exécution P7Z détaillés (NEW)
pub.v_isa_sovereign_fragility     — fragilité souveraine P7Z (NEW)
```

---

# 4. Schéma MG — gouvernance de publication

## 4.1 mg.release_registry

| release_code | status | version | données |
|---|---|---|---|
| P8V2_2026_CANDIDATE | ACTIVE_CANDIDATE | 2.0.0-candidate | 2010–2024 |

## 4.2 mg.publication_registry — 10 datasets

| Famille | Dataset | Accès |
|---------|---------|-------|
| COUNTRY | ISA_COUNTRY_LATEST, ISA_COUNTRY_HISTORY, ISA_COUNTRY_RANKINGS | PUBLIC |
| PILLAR | ISA_PILLAR_BREAKDOWN | PUBLIC |
| OPPORTUNITY | ISA_OPPORTUNITIES | PUBLIC_LIMITED |
| METHODOLOGY | ISA_METHODOLOGY, ISA_RELEASE_MANIFEST | PUBLIC |
| PREDICTIVE | ISA_P7Z_READINESS, ISA_SOVEREIGN_FRAGILITY | PUBLIC |
| PREDICTIVE | ISA_P7Z_SIGNALS | EXPERT |

## 4.3 mg.api_contract_registry — 12 endpoints

| Endpoint | Méthode | Accès | Auth |
|----------|---------|-------|------|
| V2_COUNTRIES_LIST | GET /api/v2/countries | PUBLIC | Non |
| V2_COUNTRY_HISTORY | GET /api/v2/countries/{iso3}/history | PUBLIC | Non |
| V2_COUNTRY_PILLARS | GET /api/v2/countries/{iso3}/pillars | PUBLIC | Non |
| V2_RANKINGS_LATEST | GET /api/v2/rankings/latest | PUBLIC | Non |
| V2_RANKINGS_YEAR | GET /api/v2/rankings/year/{year} | PUBLIC | Non |
| V2_OPPORTUNITIES | GET /api/v2/opportunities | PUBLIC_LIMITED | Non |
| V2_METHODOLOGY | GET /api/v2/methodology | PUBLIC | Non |
| V2_RELEASE | GET /api/v2/release | PUBLIC | Non |
| V2_P7Z_READINESS | GET /api/v2/predictive/readiness | PUBLIC | Non |
| V2_P7Z_READINESS_ISO3 | GET /api/v2/predictive/readiness/{iso3} | PUBLIC | Non |
| V2_P7Z_SIGNALS | GET /api/v2/predictive/signals | EXPERT | **Oui** |
| V2_SOVEREIGN_FRAGILITY | GET /api/v2/predictive/fragility | PUBLIC | Non |

---

# 5. P7Z Phase 2 dans P8 V2

## 5.1 pub.v_isa_p7z_country_readiness

Vue agrégée par pays/année. Répond à : quels pays sont prêts pour une exécution prédictive ?

```sql
SELECT country_iso3, year,
       nb_simulation_ready, avg_execution_probability,
       min_convergence_years, sovereign_fragility_class
FROM pub.v_isa_p7z_country_readiness
WHERE year = 2024
ORDER BY avg_execution_probability DESC;
```

## 5.2 pub.v_isa_p7z_execution_signals (EXPERT)

Signaux détaillés avec composantes de probabilité. Accès authentifié.

```sql
-- Accès expert uniquement
SELECT country_iso3, year, pillar_code,
       execution_probability, confidence_interval,
       prob_base, prob_scenario, prob_decision
FROM pub.v_isa_p7z_execution_signals
WHERE country_iso3 = 'MAR' AND year = 2024;
```

## 5.3 pub.v_isa_sovereign_fragility

Index de fragilité souveraine nationale.

```sql
SELECT country_iso3, year,
       sovereign_fragility_index, sovereign_fragility_class,
       most_fragile_pillar, p7z_national_status
FROM pub.v_isa_sovereign_fragility
WHERE year = 2024
ORDER BY sovereign_fragility_index DESC;
```

---

# 6. Enrichissement pub.v_isa_country_latest

La vue `pub.v_isa_country_latest` agrège trois couches :

```text
ma.v_isa_observed_scores_by_country_year  →  scores ISA
ma.v_isa_decision_country_year            →  country_decision_class (P7J)
ma.v_isa_p7z_fragility_engine             →  sovereign_fragility_class (P7Z)
```

C'est la première vue OSA qui expose simultanément observation + décision + prédiction.

---

# 7. Coexistence P8OPS / P8V2

| Package | Status | Rôle |
|---------|--------|------|
| P8OPS | LEGACY_ACTIVE | Publication legacy — maintenu pendant validation |
| P8V2 | ACTIVE_CANDIDATE | Nouvelle couche pub.* — validation en parallèle |

P8V2 remplacera P8OPS après validation complète du schéma `pub` et des endpoints v2.

---

# 8. Ordre d'exécution

```text
1. db/patch_db/patch_mg_check_helpers.sql    (si non installé)
2. db/patch_db/patch_p8_v2_foundation_v2.sql
3. audit/audit_p8_v2_foundation_v2.sql
```

Script : `db/run/run_p8_v2_foundation_v2.ps1`

---

# 9. Commit

```bash
git add db/patch_db/patch_p8_v2_foundation_v2.sql \
        db/run/run_p8_v2_foundation_v2.ps1 \
        audit/audit_p8_v2_foundation_v2.sql \
        README_p8_v2_foundation_v2.md

git commit -m "fix(p8): P8 V2 foundation V2 — fix orphan SQL, create pub views, integrate P7Z Phase 2"

git push origin main
```

---

# 10. Suite — P8 V2 Lot 1

P8 V2 Foundation installe l'infrastructure de publication. Le Lot 1 ajoutera :

| Lot | Contenu |
|-----|---------|
| Lot 1 | pub.v_isa_executive_decisions (P7K), pub.v_isa_p7z_convergence_map, dry run complet |
| Lot 2 | API Python routes, pagination, filtres iso3/year |
| Lot 3 | Archive layer, versionning des releases, changelog public |
