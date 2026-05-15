# P7I — ISA Early Warning & Risk Intelligence Engine

## Mission

P7I transforme :

- P7F — Strategic Diagnostic Intelligence
- P7G — Forecast Intelligence
- P7H — Scenario Simulation Intelligence

En alertes souveraines :

- `GREEN`
- `YELLOW`
- `ORANGE`
- `RED`

Il produit également :

- risk escalation
- fragility warnings
- stress propagation
- priority intervention alerts

## Doctrine

P7I est une couche d'alerte et de risque. Elle ne publie pas, ne certifie pas et ne monétise pas.

Elle prépare P7J, qui transformera les diagnostics, forecasts, scénarios et alertes en opportunités priorisées.

## Architecture

```text
db/patch_db/patch_p7i_early_warning_risk.sql

db/views/ma/v_p7i_risk_source.sql
db/views/ma/v_isa_early_warning_engine.sql
db/views/ma/v_isa_risk_escalation_engine.sql
db/views/ma/v_isa_fragility_warning_engine.sql
db/views/ma/v_isa_priority_intervention_alerts.sql
db/views/ma/v_isa_early_warning_country_year.sql
db/views/ma/v_isa_early_warning_readiness.sql

audit/list_p7i_source_columns.sql
audit/p7i_early_warning_risk_report.sql

db/run/run_p7i_early_warning_risk.ps1
db/run/test_p7i_dry_run.ps1
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7i_early_warning_risk.ps1
.\db\run\test_p7i_dry_run.ps1
```

## Contrôles dry-run

Le dry-run vérifie :

- existence des dépendances P7F/P7G/P7H
- colonnes critiques
- policies RF
- cardinalité pays / années / piliers
- NULL critiques
- scores bornés entre 0 et 1
- niveaux d'alerte valides
- moteur d'escalade
- priorités d'intervention

## Sorties principales

### `ma.v_isa_early_warning_engine`

Grain : pays / année / pilier.

Produit :

- `sovereign_alert_level`
- `early_warning_score`
- `early_warning_confidence`
- `sovereign_risk_score`
- `fragility_warning_score`
- `stress_propagation_score`
- `early_warning_decision`

### `ma.v_isa_early_warning_country_year`

Grain : pays / année.

Produit : niveau d'alerte pays.

### `ma.v_isa_priority_intervention_alerts`

Relie les alertes P7I aux interventions candidates P7F.

## Chaîne analytique

```text
P7E → P7F → P7G → P7H → P7I
Observed → Diagnostic → Forecast → Simulation → Early Warning
```
