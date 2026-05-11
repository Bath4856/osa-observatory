# OSA / ISA — P7B4 Semantic Forecastability Engine

## Objectif

P7B4 transforme les politiques opérationnelles P7B3 en décisions de forecast :

- `FORECAST_READY`
- `FORECAST_LIMITED`
- `CONTEXT_ONLY`
- `FORECAST_DISABLED`
- `FORECAST_DISABLED_REVIEW`

Le principe central reste celui d'OSA : **ne pas exclure les signaux faibles**, mais les qualifier correctement pour l'ISA, l'imputation, le ML et les prévisions.

## Dépendances validées

P7B4 consomme principalement :

```text
ma.v_isa_semantic_operations
```

et crée :

```text
rf.semantic_forecast_policy
ma.v_semantic_forecastability_engine
ma.v_isa_forecast_readiness
```

## Installation

```powershell
cd G:\osa-observatory
.\db\run\run_p7b4_semantic_forecastability.ps1
```

Mot de passe PostgreSQL attendu si votre `.env` est inchangé :

```text
osa2026
```

## Test dry-run

```powershell
.\db\run\test_p7b4_dry_run.ps1
```

Le dry-run vérifie :

- l'existence de la table de politique forecast,
- l'existence des vues P7B4,
- le nombre d'indicateurs forecastables,
- la distribution des statuts forecast,
- la distribution des décisions ML forecast,
- les scores moyens par pilier.

## Doctrine

- Les signaux `EVENT` ne sont pas forecastés structurellement : ils restent monitorés.
- Les signaux `PHYSICAL` verrouillés ne sont pas forecastés tant que la certification n'est pas acquise.
- Les signaux `STRUCTURAL`, `STOCK`, `PHYSICAL` certifiés sont les meilleurs candidats au forecast.
- Les signaux `GEO`, `PRESSURE`, `DEPENDENCY` sont utilisés avec prudence comme contexte ou forecast limité.
