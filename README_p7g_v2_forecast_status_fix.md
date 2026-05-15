# P7G v2 — Forecast Status Fix

Correction production ciblée de `ma.v_isa_forecast_trend_engine`.

## Objet

Corriger le statut PGEO : l'historique existe, mais la confiance d'observation est insuffisante. PGEO ne doit donc pas être classé en `FORECAST_DISABLED_INSUFFICIENT_HISTORY`, mais en :

```text
FORECAST_DISABLED_LOW_CONFIDENCE
```

avec :

```text
forecast_warning_level = LOW_CONFIDENCE
```

## Fichiers

```text
db/views/ma/v_isa_forecast_trend_engine.sql
audit/p7g_v2_forecast_status_fix_report.sql
db/run/run_p7g_v2_fix_forecast_status.ps1
db/run/test_p7g_v2_fix_dry_run.ps1
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7g_v2_fix_forecast_status.ps1
.\db\run\test_p7g_v2_fix_dry_run.ps1
```

## Validation attendue

```text
PGEO -> FORECAST_DISABLED_LOW_CONFIDENCE
nb_pillars trend = 10
critical_nulls = 0
```
