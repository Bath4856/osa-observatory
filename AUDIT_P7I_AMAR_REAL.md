# Audit réel — P7I existant et extension P7I-AMAR

## 1. Source de l’audit

Audit établi à partir du résultat transmis après exécution de :

```powershell
Get-ChildItem -Recurse | Where-Object {
    $_.Name -match "p7i|early_warning|risk"
} | Select-Object FullName
```

et surtout :

```powershell
psql -h 127.0.0.1 -U postgres -d osa_db -f audit/list_p7i_source_columns.sql
```

Le résultat confirme que P7I est déjà un moteur complet, connecté à P7F, P7G et P7H.

## 2. Verdict d’architecture

Décision confirmée :

```text
KEEP P7G
KEEP P7I CORE
EXTEND P7I WITH AMAR
OPTIONALLY ENRICH P7H SCENARIOS
```

Il ne faut pas recréer :

```text
ma.v_p7i_risk_source
ma.v_isa_early_warning_engine
ma.v_isa_risk_escalation_engine
ma.v_isa_early_warning_country_year
ma.v_isa_early_warning_readiness
```

## 3. P7I existant confirmé

### 3.1 Source consolidée P7I

Vue existante :

```text
ma.v_p7i_risk_source
```

Colonnes confirmées et utilisées par P7I-AMAR :

```text
country_iso3
year
pillar_code
publication_status
publication_decision
isa_observed_score
sovereignty_observed_score
vulnerability_observed_score
resilience_observed_score
data_completeness
observation_confidence
weakness_score
threat_score
strength_score
opportunity_score
strategic_risk_score
strategic_upside_score
diagnostic_priority_score
strategic_diagnostic_role
strategic_attention_class
swot_data_status
history_years
forecast_observation_confidence
isa_trend_slope
isa_volatility
forecast_policy_code
forecast_trend_class
forecast_trend_status
forecast_blocking_reason
central_isa_delta
ambitious_isa_delta
stress_isa_delta
central_simulation_confidence
ambitious_simulation_confidence
stress_simulation_confidence
central_simulation_decision
stress_simulation_decision
```

### 3.2 Core engine P7I

Vue existante :

```text
ma.v_isa_early_warning_engine
```

Colonnes opérationnelles confirmées :

```text
sovereign_risk_score
fragility_warning_score
stress_propagation_score
early_warning_score
early_warning_confidence
sovereign_alert_level
alert_rank
alert_label
recommended_governance_action
early_warning_decision
early_warning_class
```

### 3.3 Escalation engine

Vue existante :

```text
ma.v_isa_risk_escalation_engine
```

Colonnes confirmées :

```text
previous_alert_level
previous_alert_rank
risk_delta
alert_rank_delta
risk_escalation_class
risk_escalation_label
risk_escalation_action
escalation_reason
```

### 3.4 Agrégation pays/année

Vue existante :

```text
ma.v_isa_early_warning_country_year
```

Colonnes confirmées :

```text
country_early_warning_score
country_early_warning_confidence
nb_red_alerts
nb_orange_alerts
nb_yellow_alerts
nb_green_alerts
country_sovereign_alert_level
country_early_warning_status
```

## 4. Correction majeure du pack initial

Le premier pack avait une incohérence d’échelle :

- le score AMAR était construit sur une échelle `0–1`
- les seuils étaient écrits comme `25 / 45 / 65 / 80`

Conséquence : presque tous les résultats auraient été classés `GREEN`.

Correction v2 :

```text
GREEN  < 0.25
YELLOW < 0.45
ORANGE < 0.65
RED    < 0.80
BLACK  >= 0.80
```

Le score final est aussi plafonné :

```sql
LEAST(1.000, GREATEST(0.000, ...))
```

## 5. Ce que P7I-AMAR ajoute

P7I-AMAR ajoute uniquement un domaine métier :

```text
ATROCITY_PRECURSOR
CIVILIAN_PROTECTION
```

Il ne prétend pas prédire juridiquement un génocide. Il produit un signal d’alerte précoce pour la protection des civils.

## 6. Fichiers de production fournis

```text
db/patch_db/patch_p7i_amar_extension.sql
db/views/ma/v_p7i_amar_atrocity_precursor_engine.sql
db/views/ma/v_p7i_amar_dashboard.sql
db/views/mg/v_public_p7i_amar_alerts.sql
db/patch_db/patch_p7i_amar_alert_refresh.sql
audit/list_p7i_amar_columns.sql
audit/p7i_amar_report.sql
db/run/run_p7i_amar_extension.ps1
db/run/test_p7i_amar_dry_run.ps1
db/patch_db/rollback_p7i_amar_extension.sql
db/run/rollback_p7i_amar_extension.ps1
README_p7i_amar_extension.md
MANIFEST_P7I_AMAR.txt
```

## 7. Conclusion

Le pack v2 est un vrai merge pack : il ajoute AMAR sans casser P7I Core.
