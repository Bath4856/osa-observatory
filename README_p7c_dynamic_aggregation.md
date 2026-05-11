# P7C — ISA Dynamic Aggregation Engine

## Objectif

P7C transforme les sorties P7B1→P7B6 en moteur d’agrégation dynamique ISA.

Il prépare le passage de :

```text
ISA = Σ(indicateur × poids fixe)
```

à :

```text
ISA_DYNAMIC = Σ(indicateur × poids stratégique dynamique)
```

## Dépendance principale

P7C s’appuie uniquement sur le contrat validé :

```text
ma.v_semantic_strategic_weighting_engine
```

## Livrables

```text
db/patch_db/patch_p7c_dynamic_aggregation.sql
db/views/ma/v_semantic_dynamic_aggregation_engine.sql
db/views/ma/v_isa_dynamic_aggregation_readiness.sql
audit/p7c_dynamic_aggregation_report.sql
db/run/run_p7c_dynamic_aggregation.ps1
db/run/test_p7c_dry_run.ps1
README_p7c_dynamic_aggregation.md
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7c_dynamic_aggregation.ps1
.\db\run\test_p7c_dry_run.ps1
```

## Contrôles intégrés

Le dry-run teste :

- existence des dépendances ;
- colonnes via `information_schema.columns` ;
- couverture 228 indicateurs ;
- anti-NULL ;
- anti-division zéro potentielle ;
- cardinalité readiness ;
- conservation des gaps verrouillés.

## Sorties principales

```text
final_isa_aggregation_weight
final_ml_aggregation_weight
final_forecast_aggregation_weight
final_sovereignty_aggregation_weight
final_vulnerability_aggregation_weight
```

## Doctrine

Les signaux faibles ne sont pas supprimés. Ils sont qualifiés :

- core ISA ;
- controlled ISA ;
- vulnerability index ;
- locked gap ;
- context only.
