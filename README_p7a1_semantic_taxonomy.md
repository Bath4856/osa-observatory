# OSA / ISA — P7A1 Semantic Taxonomy Foundation

## Objectif

P7A1 introduit une taxonomie sémantique ISA pour qualifier les signaux au-delà de leur simple nature statistique.

Le but est de réduire fortement les indicateurs `UNCLASSIFIED` et de préparer P7B/P8 : dépendances inter-piliers, causalité, ML et recommandations de projets structurants.

## Fichiers

```text
db/patch_db/patch_p7a1_semantic_taxonomy.sql
db/views/ma/v_signal_semantic_engine.sql
db/run/run_p7a1_semantic_engine.ps1
db/run/test_p7a1_dry_run.ps1
audit/p7a1_semantic_report.sql
README_p7a1_semantic_taxonomy.md
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7a1_semantic_engine.ps1
```

## Test à blanc

```powershell
cd G:\osa-observatory
.\db\run\test_p7a1_dry_run.ps1
```

## Taxonomie

- PHYSICAL
- STRUCTURAL
- FLOW
- STOCK
- EVENT
- PRESSURE
- DEPENDENCY
- RESILIENCE
- GOVERNANCE
- NETWORK
- PERCEPTION
- COMPOSITE
- GEO
- UNCLASSIFIED

## Principe

P7A1 ne modifie pas les données. Il ajoute une couche sémantique gouvernée, calculée par :

1. `rf.indicator_nature` si disponible ;
2. heuristiques par code indicateur ;
3. fallback par pilier.

## Résultat attendu

- Forte baisse des signaux non classés ;
- meilleure interprétation P6 ;
- base préparée pour P7B Semantic Dependency Engine.
