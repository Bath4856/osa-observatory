# P7B5 — Semantic Sovereignty Engine

## Objectif

P7B5 transforme les signaux sémantiques gouvernés en **score transversal de souveraineté sémantique**.

Il ne supprime aucun indicateur. Il qualifie chaque signal selon :

- son poids de souveraineté,
- sa confiance dynamique,
- son statut opérationnel,
- sa forecastabilité,
- sa dépendance,
- sa résilience,
- son poids physique,
- son statut de revue/verrouillage.

## Dépendances

P7B5 dépend uniquement du contrat validé P7B4 :

```text
ma.v_semantic_forecastability_engine
ma.v_isa_forecast_readiness
rf.semantic_forecast_policy
```

## Livrables

```text
db/patch_db/patch_p7b5_semantic_sovereignty.sql
db/views/ma/v_semantic_sovereignty_engine.sql
db/views/ma/v_isa_sovereignty_readiness.sql
audit/p7b5_semantic_sovereignty_report.sql
db/run/run_p7b5_semantic_sovereignty.ps1
db/run/test_p7b5_dry_run.ps1
README_p7b5_semantic_sovereignty.md
```

## Installation

```powershell
cd G:\osa-observatory
.\db\run\run_p7b5_semantic_sovereignty.ps1
```

## Test

```powershell
.\db\run\test_p7b5_dry_run.ps1
```

## Philosophie OSA

P7B5 respecte la doctrine :

```text
Un signal faible n’est pas supprimé.
Il devient une vulnérabilité souveraine qualifiée.
```

Les signaux verrouillés sont conservés dans ISA comme :

```text
USE_AS_STRUCTURAL_GAP
```

Les signaux robustes sont intégrés comme :

```text
USE_IN_ISA_WEIGHTED_CORE
```

## Suite logique

Après P7B5 :

```text
P7B6 — Semantic Risk & Vulnerability Engine
```
