# OSA / ISA — P7F Strategic Diagnostic Intelligence Engine

## 1. Purpose

P7F is the clean diagnostic successor to the transitional P7X layer.

Doctrine:

```text
P7E observes.
P7F diagnoses.
P7F does not forecast.
P7F does not simulate.
P7F does not certify.
P7F does not generate premium feasibility triggers.
```

P7F converts observed ISA pillar scores and computed SWOT indicators into:

- strategic diagnostic signals;
- candidate intervention catalog;
- public consultation topics.

Validated opportunities, forecasts, scenario impacts, feasibility studies, and premium investment packages are reserved for later packages, especially P7G/P7H/P7I/P7J.

---

## 2. Package contents

```text
db/patch_db/patch_p7f_strategic_diagnostic_intelligence.sql

db/views/ma/v_p7f_computed_swot_source.sql
db/views/ma/v_p7f_observed_pillar_source.sql
db/views/ma/v_isa_strategic_diagnostic_engine.sql
db/views/ma/v_isa_candidate_intervention_catalog.sql
db/views/ma/v_isa_public_consultation_topics.sql

audit/list_p7f_source_columns.sql
audit/p7f_strategic_diagnostic_report.sql

db/run/run_p7f_strategic_diagnostic.ps1
db/run/test_p7f_dry_run.ps1

README_p7f_strategic_diagnostic.md
```

---

## 3. Dependencies

Required:

```text
ma.v_isa_observed_scores_by_pillar
ma.computed_values
```

Expected confirmed columns from `ma.v_isa_observed_scores_by_pillar`:

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
avg_observation_confidence
```

Expected confirmed columns from `ma.computed_values`:

```text
indicator_code
country_iso3
year
value
confidence
```

P7F tolerates `STR_*` and `OPP_*` being absent, but expects `WKN_*` and `THR_*` to exist.

---

## 4. Outputs

### `ma.v_isa_strategic_diagnostic_engine`

Main diagnostic view at country-year-pillar level.

Key outputs:

```text
weakness_score
threat_score
strength_score
opportunity_score
strategic_risk_score
strategic_upside_score
strategic_diagnostic_role
strategic_attention_class
diagnostic_priority_score
```

### `ma.v_isa_candidate_intervention_catalog`

Candidate intervention catalog.

Important: these are diagnostic candidates only.
They are not forecast-backed and not premium feasibility triggers.

### `ma.v_isa_public_consultation_topics`

Public consultation topics derived from diagnostic evidence.

---

## 5. Execution

```powershell
cd G:\osa-observatory
.\db\run\run_p7f_strategic_diagnostic.ps1
.\db\run\test_p7f_dry_run.ps1
```

---

## 6. Dry-run controls

The dry-run checks:

- dependency existence;
- required source columns;
- WKN presence;
- THR presence;
- tolerance for STR/OPP;
- diagnostic cardinality;
- anti-NULL controls;
- score bounds;
- no premium / no forecast validation leakage;
- P7X archived and P7F active in `mg.package_lifecycle`.

---

## 7. Git commit

```powershell
git add `
  db/patch_db/patch_p7f_strategic_diagnostic_intelligence.sql `
  db/views/ma/v_p7f_computed_swot_source.sql `
  db/views/ma/v_p7f_observed_pillar_source.sql `
  db/views/ma/v_isa_strategic_diagnostic_engine.sql `
  db/views/ma/v_isa_candidate_intervention_catalog.sql `
  db/views/ma/v_isa_public_consultation_topics.sql `
  audit/list_p7f_source_columns.sql `
  audit/p7f_strategic_diagnostic_report.sql `
  db/run/run_p7f_strategic_diagnostic.ps1 `
  db/run/test_p7f_dry_run.ps1 `
  README_p7f_strategic_diagnostic.md

git commit -m "feat(p7f): add ISA strategic diagnostic intelligence engine"

git push origin main
```
