# P7X — ISA Strategic SWOT Intelligence Engine

P7X est une couche d'intelligence stratégique séparée de P7E.

- P7E publie ce qui est observé.
- P7X transforme l'observation en recommandations, projets, opportunités, déclencheurs premium et priorités d'e-participation.
- P7X ne modifie jamais les scores ISA publiés.

## Architecture

```text
db/patch_db/patch_p7x_swot_strategic_intelligence.sql
db/views/ma/v_isa_swot_signal_engine.sql
db/views/ma/v_isa_strategic_recommendation_engine.sql
db/views/ma/v_isa_project_opportunity_catalog.sql
db/views/ma/v_isa_premium_feasibility_triggers.sql
db/views/ma/v_isa_eparticipation_priorities.sql
audit/list_p7x_source_columns.sql
audit/p7x_swot_strategic_intelligence_report.sql
db/run/run_p7x_swot_strategic_intelligence.ps1
db/run/test_p7x_dry_run.ps1
```

## Correction v2

Cette version n'utilise plus directement `computed_code`.
Elle crée une vue de compatibilité :

```text
ma.v_p7x_computed_swot_source
```

Cette vue détecte automatiquement les colonnes disponibles dans `ma.computed_values` parmi :

- code : `computed_code`, `indicator_code`, `code`, `metric_code`, `signal_code`, `name`
- pays : `country_iso3`, `iso3`, `country_code`
- année : `year`, `annee`
- valeur : `computed_value`, `value`, `processed_value`, `score`, `raw_value`

Elle expose ensuite des colonnes stables :

```text
swot_code
swot_type
country_iso3
year
pillar_code
swot_value
compatibility_status
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7x_swot_strategic_intelligence.ps1
.\db\run\test_p7x_dry_run.ps1
```

## Dry-run

Le dry-run teste :

- existence dépendances
- listing colonnes sources
- présence WKN_*
- présence THR_*
- tolérance STR_/OPP_ absents
- anti-NULL
- cardinalité pays/pilier/année
- recommandations
- projets générés
- triggers premium

## Doctrine

```text
P7X = intelligence stratégique
P7X ≠ recalcul ISA
P7X ≠ publication officielle
```
