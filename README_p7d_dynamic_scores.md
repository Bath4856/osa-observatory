# P7D — ISA Dynamic Scores Engine

## Objectif

P7D transforme la couche P7C (`ma.v_semantic_dynamic_aggregation_engine`) en composants de scores dynamiques ISA :

- score ISA dynamique ;
- score de souveraineté ;
- score de vulnérabilité ;
- score de résilience ;
- score forecast ;
- score ML.

Cette version est volontairement prudente : elle ne joint pas encore les valeurs pays/année. Elle produit d'abord une couche de scoring stable, explicable et testable à partir du contrat P7C validé.

## Source unique

```text
ma.v_semantic_dynamic_aggregation_engine
```

## Fichiers inclus

```text
db/patch_db/patch_p7d_dynamic_scores.sql
db/views/ma/v_dynamic_scores_engine.sql
db/views/ma/v_isa_dynamic_scores_readiness.sql
audit/p7d_dynamic_scores_report.sql
audit/list_p7d_source_columns.sql
db/run/run_p7d_dynamic_scores.ps1
db/run/test_p7d_dry_run.ps1
README_p7d_dynamic_scores.md
```

## Colonnes P7C obligatoires

Le runner contrôle l'existence des colonnes suivantes avant de créer les vues P7D :

```text
indicator_code
pillar_code
indicator_name
semantic_code
semantic_confidence_dynamic
semantic_operational_score
semantic_forecastability_score
semantic_sovereignty_score
semantic_sovereignty_vulnerability
final_isa_aggregation_weight
final_ml_aggregation_weight
final_forecast_aggregation_weight
final_sovereignty_aggregation_weight
final_vulnerability_aggregation_weight
dynamic_aggregation_class
dynamic_isa_aggregation_decision
dynamic_ml_aggregation_decision
dynamic_forecast_aggregation_decision
systemic_vulnerability_class
semantic_sovereignty_class
```

## Installation

Depuis la racine du dépôt :

```powershell
cd G:\osa-observatory
.\db\run\run_p7d_dynamic_scores.ps1
.\db\run\test_p7d_dry_run.ps1
```

## Tests dry-run inclus

Le dry-run vérifie :

- existence de `rf.dynamic_score_policy` ;
- existence de `ma.v_dynamic_scores_engine` ;
- existence de `ma.v_isa_dynamic_scores_readiness` ;
- contrôle des colonnes source P7C via `information_schema.columns` ;
- cardinalité des politiques RF ;
- couverture des 228 indicateurs ;
- absence de NULL critiques ;
- bornage des scores entre 0 et 1.5 ;
- classes et décisions de scoring ;
- lignes readiness ;
- gaps verrouillés.

## Principe doctrinal

P7D ne confond pas performance et souveraineté :

- `PHYSICAL`, `STOCK`, `STRUCTURAL` peuvent renforcer le score ISA ;
- `EVENT`, `DEPENDENCY`, `PRESSURE` contribuent surtout à la vulnérabilité ;
- les signaux verrouillés restent conservés mais ne doivent pas entrer dans le score ISA central avant revue.

## Suite logique

P7D2 pourra joindre ces composants de score à une table de valeurs normalisées pays/année lorsque le contrat exact de la table source sera validé.

Candidats possibles à vérifier avant P7D2 :

```text
ma.indicator_values_final
ma.indicator_values_clean
ma.normalized_indicator_values
```

Ne pas joindre ces tables tant que leurs colonnes réelles n'ont pas été listées et validées.
