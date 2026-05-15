# P7J — ISA Decision Support & Intervention Prioritization

## Mission

P7J transforme les couches déjà validées :

```text
P7F — Strategic Diagnostic Intelligence
P7H — Scenario Simulation Intelligence
P7I — Early Warning & Risk Intelligence
```

en une matrice décisionnelle :

```text
quoi faire,
où intervenir,
quand intervenir,
avec quelle priorité,
et avec quel niveau de confiance.
```

P7J ne certifie pas, ne publie pas et ne monétise pas. Il prépare la décision avant P8.

---

## Dépendances strictes

P7J exige :

```text
ma.v_isa_priority_intervention_alerts
ma.v_isa_scenario_simulation_engine
ma.v_isa_early_warning_engine
```

Le script `run_p7j_decision_support.ps1` contrôle les dépendances et les colonnes avant les requêtes métier.

---

## Fichiers

```text
db/patch_db/patch_p7j_decision_support.sql

db/views/ma/v_p7j_decision_source.sql
db/views/ma/v_isa_decision_priority_engine.sql
db/views/ma/v_isa_intervention_decision_matrix.sql
db/views/ma/v_isa_decision_country_year.sql
db/views/ma/v_isa_decision_readiness.sql

audit/list_p7j_source_columns.sql
audit/p7j_decision_support_report.sql

db/run/run_p7j_decision_support.ps1
db/run/test_p7j_dry_run.ps1
README_p7j_decision_support.md
```

---

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7j_decision_support.ps1
.\db\run\test_p7j_dry_run.ps1
```

---

## Sorties principales

### `ma.v_isa_decision_priority_engine`

Vue centrale P7J.

Colonnes clés :

```text
country_iso3
year
pillar_code
intervention_family_code
sovereign_alert_level
early_warning_score
intervention_alert_priority_score
central_isa_delta
ambitious_isa_delta
stress_isa_delta
decision_priority_score
decision_confidence_score
decision_priority_class
decision_timing_code
governance_track
public_decision_scope
decision_support_status
```

### `ma.v_isa_intervention_decision_matrix`

Matrice actionnable :

```text
DO_NOW
PRIORITIZE_NEXT_CYCLE
PREPARE_OPPORTUNITY_NOTE
MONITOR_AND_DOCUMENT
```

### `ma.v_isa_decision_country_year`

Synthèse pays/année :

```text
COUNTRY_DECISION_CRITICAL
COUNTRY_DECISION_HIGH
COUNTRY_DECISION_STANDARD
COUNTRY_DECISION_MONITOR
```

---

## Classes de priorité

```text
DECISION_CRITICAL
DECISION_HIGH
DECISION_STANDARD
DECISION_MONITOR
```

## Temporalité décisionnelle

```text
IMMEDIATE_0_3_MONTHS
SHORT_TERM_3_12_MONTHS
MEDIUM_TERM_1_3_YEARS
MONITORING_ONLY
```

---

## Contrôles dry-run

Le dry-run vérifie :

```text
existence des politiques
existence des vues
colonnes obligatoires
volumétrie source
anti-NULL critique
scores bornés 0..1
classes valides
codes de timing valides
cardinalité pays / années / piliers
répartition des priorités
```

---

## Position dans la chaîne P7

```text
P7E → P7F → P7G → P7H → P7I → P7J
Observed → Diagnostic → Forecast → Simulation → Early Warning → Decision Support
```

P7J est la dernière couche analytique décisionnelle avant P8 Ops.
