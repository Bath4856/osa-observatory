# P7E — ISA Observed Publication Engine

## Mission

P7E transforme les valeurs observées en scores ISA publiables, selon la doctrine OSA :

> Ce qui est publié est ce qui a été observé.

P7E ne fusionne pas les indicateurs SWOT. La couche SWOT sera traitée séparément dans un package P7X, pour l’intelligence stratégique, les projets structurants, les études d’opportunité, les études de faisabilité et l’e-participation.

## Sources strictes

### 1. `ma.indicator_values_final`

Colonnes requises :

```text
country_iso3
year
indicator_code
processed_value
confidence_score
confidence_score

Optional source fields such as `is_estimated` and `quality_flag` are not required in this corrected v2 package. The engine emits safe defaults:

```text
is_estimated = false
quality_flag = OBSERVED_NO_QUALITY_FLAG
```
```

### 2. `ma.v_dynamic_scores_engine`

Colonnes requises :

```text
indicator_code
pillar_code
semantic_code
dynamic_isa_score_component
dynamic_sovereignty_score_component
dynamic_vulnerability_score_component
dynamic_resilience_score_component
dynamic_forecast_score_component
dynamic_ml_score_component
dynamic_score_class
dynamic_score_decision
```

## Sorties

```text
ma.v_isa_observed_publication_engine
ma.v_isa_observed_scores_by_pillar
ma.v_isa_observed_scores_by_country_year
ma.v_isa_observed_scores_by_region_year
ma.v_isa_observed_publication_readiness
```

## Scores produits

```text
isa_observed_score
sovereignty_observed_score
vulnerability_observed_score
resilience_observed_score
forecast_readiness_score
ml_readiness_score
```

## Gouvernance publication

Statuts automatiques :

```text
OFFICIAL_CONSOLIDATED
PROVISIONAL_N1
CURRENT_YEAR_MONITORING
EXCLUDED_NOT_READY
NO_OBSERVED_DATA
```

Règle temporelle :

```text
N = année courante
N-6 à N-2 = publication officielle consolidée sur 5 ans
N-1 = score provisoire, données incomplètes ou en cours de consolidation
N = monitoring courant, non publié officiellement
```

## Régions

P7E évite toute dépendance incertaine aux tables pays/régions existantes. Il crée :

```text
rf.isa_country_region_override
```

Cette table peut être alimentée ensuite avec :

```text
country_iso3
region_code
economic_region_code
region_label
economic_region_label
```

Si aucune région n’est fournie, les vues utilisent `UNSPECIFIED`.

## Installation

```powershell
cd G:\osa-observatory
.\db\run\run_p7e_observed_publication.ps1
.\db\run\test_p7e_dry_run.ps1
```

## Fichiers

```text
db/patch_db/patch_p7e_observed_publication.sql
db/views/ma/v_isa_observed_publication_engine.sql
db/views/ma/v_isa_observed_scores_by_pillar.sql
db/views/ma/v_isa_observed_scores_by_country_year.sql
db/views/ma/v_isa_observed_scores_by_region_year.sql
db/views/ma/v_isa_observed_publication_readiness.sql
audit/list_p7e_source_columns.sql
audit/p7e_observed_publication_report.sql
db/run/run_p7e_observed_publication.ps1
db/run/test_p7e_dry_run.ps1
```

## Principes de prudence

- prétest dépendances avant vues métier ;
- liste des colonnes sources ;
- anti-NULL critiques ;
- bornage scores entre 0 et 1.5 ;
- anti-division zéro par `NULLIF` ;
- aucune colonne régionale incertaine ;
- aucun SWOT injecté dans le score publié.
