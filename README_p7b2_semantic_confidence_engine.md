# P7B2 — Semantic Confidence Engine

## Objectif

P7B2 transforme la confiance sémantique statique issue de P7A/P7B1 en confiance dynamique gouvernée.

Le moteur combine :

- confiance sémantique P7A ;
- classe de gouvernance P7B1 ;
- statut stratégique/hybride ;
- volatilité sémantique ;
- priorité ML ;
- pénalités spécifiques aux signaux physiques, événementiels ou critiques.

## Fichiers

```text
db/patch_db/patch_p7b2_semantic_confidence_engine.sql
db/views/ma/v_semantic_confidence_engine.sql
db/views/ma/v_semantic_confidence_priority.sql
audit/p7b2_semantic_confidence_report.sql
db/run/run_p7b2_semantic_confidence.ps1
db/run/test_p7b2_dry_run.ps1
README_p7b2_semantic_confidence_engine.md
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7b2_semantic_confidence.ps1
.\db\run\test_p7b2_dry_run.ps1
```

## Principe

P7B2 n’exclut aucun signal. Il qualifie la confiance dynamique et verrouille les signaux critiques jusqu’à revue humaine.

Exemples :

- PHYSICAL critique → `CONFIDENCE_LOCKED_REVIEW`
- EVENT faible → `LIMIT_EVENT_INFERENCE`
- gouverné fort → `READY_FOR_STRONG_USE`
- gouverné acceptable → `READY_WITH_CAUTION`

## Sorties principales

```text
ma.v_semantic_confidence_engine
ma.v_semantic_confidence_priority
```

Ces vues seront utilisées par P7B3 pour la politique d’imputation sémantique.
