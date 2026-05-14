# P7J v2 — Decision Support Recalibration

## Mission

P7J v2 corrige le moteur de décision P7J :

1. plafonnement métier par niveau d’alerte souveraine ;
2. interdiction de `YELLOW -> DECISION_CRITICAL` ;
3. interdiction de `GREEN -> DECISION_HIGH/DECISION_CRITICAL` ;
4. agrégation pays plus stricte ;
5. dry-run renforcé anti-régression.

## Règle de plafonnement

| Alerte | Classe décisionnelle maximale |
|---|---|
| GREEN | DECISION_STANDARD |
| YELLOW | DECISION_HIGH |
| ORANGE | DECISION_CRITICAL |
| RED | DECISION_CRITICAL |

## Agrégation pays v2

```text
country_decision_priority_score =
    0.45 * max(decision_priority_score)
  + 0.30 * avg(top 3 decision_priority_score)
  + 0.15 * critical_ratio
  + 0.10 * avg(decision_confidence_score)
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7j_v2_decision_recalibration.ps1
.\db\run\test_p7j_dry_run.ps1
```

## Contrôles attendus

```sql
SELECT COUNT(*)
FROM ma.v_isa_decision_priority_engine
WHERE sovereign_alert_level = 'YELLOW'
  AND decision_priority_class = 'DECISION_CRITICAL';
-- attendu : 0
```

```sql
SELECT COUNT(*)
FROM ma.v_isa_decision_priority_engine
WHERE sovereign_alert_level = 'GREEN'
  AND decision_priority_class IN ('DECISION_HIGH','DECISION_CRITICAL');
-- attendu : 0
```

## Fichiers

```text
db/patch_db/patch_p7j_v2_decision_recalibration.sql
db/views/ma/v_isa_decision_priority_engine.sql
db/views/ma/v_isa_intervention_decision_matrix.sql
db/views/ma/v_isa_decision_country_year.sql
db/views/ma/v_isa_decision_readiness.sql
audit/p7j_v2_decision_recalibration_report.sql
db/run/run_p7j_v2_decision_recalibration.ps1
db/run/test_p7j_dry_run.ps1
README_p7j_v2_decision_recalibration.md
```
