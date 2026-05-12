# P7G — ISA Forecast Intelligence Engine

## Mission

P7G transforme :

- l’historique ISA observé issu de P7E ;
- le diagnostic stratégique issu de P7F ;

en :

- forecast scores ;
- confidence bands ;
- trend projections ;
- readiness forecast ;
- signaux prédictifs prudents.

## Doctrine

P7E observe.  
P7F diagnostique.  
P7G prévoit les tendances.  

P7G ne fait pas de simulation politique.  
P7G ne produit pas de premium trigger.  
P7G ne certifie pas.  
P7G produit une prévision déterministe, audit-able, sans modèle boîte noire.

## Fichiers

```text
db/patch_db/patch_p7g_forecast_intelligence.sql
db/views/ma/v_p7g_forecast_source.sql
db/views/ma/v_isa_forecast_trend_engine.sql
db/views/ma/v_isa_forecast_projection_engine.sql
db/views/ma/v_isa_forecast_country_year.sql
db/views/ma/v_isa_forecast_readiness_p7g.sql
audit/list_p7g_source_columns.sql
audit/p7g_forecast_intelligence_report.sql
db/run/run_p7g_forecast_intelligence.ps1
db/run/test_p7g_dry_run.ps1
README_p7g_forecast_intelligence.md
```

## Dépendances

Obligatoires :

```text
ma.v_isa_observed_scores_by_pillar
ma.v_isa_strategic_diagnostic_engine
```

## Méthode

Le moteur calcule :

- nombre d’années historiques ;
- moyenne de confiance ;
- complétude ;
- pente linéaire déterministe ;
- volatilité ;
- score projeté ;
- bande basse ;
- bande haute ;
- confiance forecast.

## Horizons

```text
H1 = 1 an
H3 = 3 ans
H5 = 5 ans
```

## Statuts

```text
FORECAST_READY_ROBUST
FORECAST_READY_CONTROLLED
FORECAST_LIMITED_INDICATIVE
FORECAST_ENABLED_WITH_VOLATILITY_WARNING
FORECAST_DISABLED_INSUFFICIENT_HISTORY
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7g_forecast_intelligence.ps1
.\db\run\test_p7g_dry_run.ps1
```

## Contrôles dry-run

Le dry-run vérifie :

- existence des dépendances ;
- colonnes sources exactes ;
- existence des vues ;
- cardinalité ;
- NULL critiques ;
- bornes de scores ;
- bandes de confiance ;
- historique non nul ;
- distribution des décisions forecast.

## Chaîne logique

```text
P7E → P7F → P7G → P7H → P7I → P7J → P8
```
