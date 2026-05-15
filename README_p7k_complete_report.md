# OSA / ISA — P7K COMPLETE REPORT

## Executive Governance Layer — Full Sprint Report

Version: P7K V3 FROZEN  
Status: FROZEN  
Scope: Executive Pre-Governance Layer + Metrological Calibration + MG Governance  
Sprint: P7K V1 → V3  
Dependencies:
- P7F (weaknesses)
- P7G (threats)
- P7H (resilience scenarios)
- P7I (early warning alerts)
- P7J (decision engine)

---

# 1. Purpose

P7K provides the executive governance preparation layer of OSA / ISA.

It transforms sovereign intervention signals into:
- executive governance portfolios,
- board-ready decision packs,
- budget arbitration matrices,
- escalation queues,
- executive governance watchlists,
- metrologically calibrated execution readiness assessments.

P7K does NOT perform:
- predictive simulation,
- probabilistic modelling,
- ISA score recalculation.

These capabilities belong to P7Z.

---

# 2. Architecture

```text
P7F → weaknesses
P7G → threats
P7H → resilience scenarios
P7I → early warning alerts
P7J → decision engine
P7K → executive governance
      ↓
      RF : scientific parameters + calibration audit
      MG : institutional model governance
      MA : executive calculations + materialized views
P7Z → predictive intelligence
P8  → publication
```

---

# 3. Sprint Summary — V1 to V3

## V1 — Executive Governance Foundation

Installed the core executive governance layer.

Objects created:
- `rf.isa_executive_governance_policy` — 4 executive decision classes
- `rf.isa_executive_budget_band_policy` — 4 budget pressure bands
- `rf.isa_executive_escalation_policy` — 4 escalation levels
- `rf.isa_executive_pillar_weight` — 10 pillar weights
- `rf.isa_intervention_family_registry` — 15 intervention families
- `ma.v_p7k_executive_source` — P7K source view (joins P7J + country year)
- `ma.v_isa_executive_priority_portfolio` — executive priority portfolio
- `ma.v_isa_budget_arbitration_matrix` — budget arbitration
- `ma.v_isa_board_decision_pack` — board-ready decision pack
- `ma.v_isa_governance_heatmap` — governance heatmap
- `ma.v_isa_executive_watchlist` — executive watchlist
- `ma.v_isa_national_escalation_queue` — national escalation queue
- `ma.v_isa_executive_governance_readiness` — executive readiness

Baseline metrics at V1:
- 8,091 rows — 54 countries — 15 years — 10 pillars
- EXEC_FAST_TRACK_CANDIDATE : 771
- EXEC_PROGRAMME_CANDIDATE : 2,370
- EXEC_WATCHLIST : 4,950

## V2 — Anomaly Corrections

Two critical anomalies identified and corrected:

**Anomaly 1** — `avg_pressure` and `avg_cost` NULL for 9 of 10 pillars.
`rf.isa_executive_cost_model` covered only `ENERGY_WATER_CERTIFICATION`.

**Anomaly 2** — `predictive_ready_flag` always FALSE.
Condition `execution_maturity_score >= 0.60` failing due to NULL values.
`COALESCE` correction applied.

## V3 — Metrological Calibration Layer (Production Baseline)

Full metrological layer introduced. P7K frozen at V3.

See section 4 for complete V3 detail.

---

# 4. P7K V3 — Metrological Calibration Layer

## 4.1 What V3 introduces

V3 transforms P7K from an analytical engine into a scientifically traceable governance system.

Three extensions introduced:

| Extension | Column | Purpose |
|-----------|--------|---------|
| Epistemic uncertainty | `calibration_uncertainty_score` | Uncertainty level of each proxy value [0–1] |
| Expiry governance | `calibration_review_due_date` | Mandatory revision deadline |
| Richer predictive status | `predictive_execution_status` | Replaces boolean `predictive_ready_flag` |

## 4.2 rf.isa_executive_cost_model V3

10 families calibrated — one per pillar.

| Pillar | Family | Maturity | Uncertainty | Source |
|--------|--------|----------|-------------|--------|
| PRES | ENERGY_WATER_CERTIFICATION | 0.55 | 0.15 | IEA Africa 2023 |
| PMON | MONETARY_FINANCIAL_RESILIENCE | 0.58 | 0.15 | IMF WEO 2023 |
| PHUM | HUMAN_CAPITAL | 0.62 | 0.15 | UNDP HDR 2023 |
| PECO | ECONOMIC_DIVERSIFICATION | 0.52 | 0.20 | UNCTAD TDR 2023 |
| PENV | ENVIRONMENTAL_RESILIENCE | 0.48 | 0.20 | UNEP NDC 2023 |
| PMIL | SECURITY_RESILIENCE | 0.42 | 0.20 | SIPRI MED 2023 |
| PMIN | MINING_VALUE_CHAIN | 0.50 | 0.25 | EITI Africa 2022 |
| PGEO | GOVERNANCE_AND_STABILITY | 0.38 | 0.15 | WB WGI 2022 |
| PNUM | DIGITAL_SOVEREIGNTY | 0.62 | 0.15 | ITU IDI 2023 |
| PTRA | TRANSPORT_LOGISTICS | 0.55 | 0.25 | WB LPI 2023 |

All values: `calibration_status = PROVISIONAL`, `calibration_review_due_date = 2027-05-15`.

## 4.3 Uncertainty rules

| Range | Meaning |
|-------|---------|
| 0.10 – 0.20 | Primary international source (IEA, IMF, UNDP, WB, ITU) |
| 0.21 – 0.30 | Secondary or regional source (UNCTAD, UNEP, SIPRI) |
| 0.31 – 0.50 | Estimated proxy, partial coverage (EITI, LPI Africa) |
| 0.51 – 0.70 | Placeholder — triggers REVIEW_REQUIRED |

## 4.4 predictive_execution_status

Replaces the boolean `predictive_ready_flag`.

| Value | Condition | Meaning |
|-------|-----------|---------|
| EXEC_READY | VALIDATED + uncertainty ≤ 0.30 + priority ≥ 0.75 + maturity ≥ 0.60 | Full predictive use |
| EXEC_READY_CAUTION | PROVISIONAL + uncertainty ≤ threshold + priority ≥ 0.75 + maturity ≥ 0.60 | Predictive use with flag |
| EXEC_BLOCKED_REVIEW | Any other case | Excluded from predictive engine |

## 4.5 predictive_gap_score

New column added to `ma.mv_isa_executive_master_board`.

```sql
predictive_gap_score = GREATEST(0, 0.75 - executive_priority_score,
                                   0.60 - execution_maturity_score)
```

Measures the distance to `EXEC_READY_CAUTION` threshold.
- 0.0 = threshold reached
- min_gap = 0.050 (PRES pillar, multiple countries)

P7Z uses this score as the convergence target variable.

---

# 5. MG — Institutional Model Governance

## 5.1 mg.isa_model_governance_policy

Institutional rules by calibration status.

| Status | MV usable | Predictive eligible | predictive_execution_value | Max uncertainty | Review |
|--------|-----------|--------------------|-----------------------------|-----------------|--------|
| VALIDATED | YES | YES | EXEC_READY | 0.30 | 24 months |
| PROVISIONAL | YES | YES | EXEC_READY_CAUTION | 0.50 | 12 months |
| REVIEW_REQUIRED | YES* | NO | EXEC_BLOCKED_REVIEW | 1.00 | 3 months |

*Visible for diagnostic only.

## 5.2 rf.isa_cost_model_audit_log

Trigger `trg_cost_model_audit` automatically logs every UPDATE on `rf.isa_executive_cost_model`.

Fields tracked: `executive_cost_score`, `implementation_complexity`, `execution_horizon_years`, `execution_maturity_score`, `calibration_uncertainty_score`, `calibration_status`, `calibration_review_due_date`, `calibration_source`.

## 5.3 mg.v_cost_model_review_due

View for monitoring upcoming revision deadlines.

| review_status | Meaning | Action |
|---------------|---------|--------|
| OVERDUE | Revision deadline passed | Revise immediately |
| DUE_SOON | Revision within 30 days | Plan revision |
| ON_TRACK | Within deadline | None required |

---

# 6. MG — Package Freeze Registry

## 6.1 P7K V3 frozen

```text
package_code    : P7K
package_version : V3
freeze_status   : FROZEN
freeze_date     : 2026-05-15 19:09
snapshot_rows   : 8,091
snapshot_countries : 54
snapshot_years  : 15
snapshot_pillars : 10
snapshot_audit_status : AUDIT_OK
```

P7K V3 is the reference baseline for P7Z Phase 1.
Any modification requires explicit UNFREEZE with documented justification.

## 6.2 Unfreeze procedure

```sql
UPDATE mg.isa_package_freeze_registry
SET freeze_status = 'UNFROZEN',
    unfrozen_date = NOW(),
    freeze_note   = freeze_note || ' | UNFROZEN: <reason>'
WHERE package_code = 'P7K' AND package_version = 'V3';

UPDATE rf.package_lifecycle
SET package_status = 'ACTIVE', updated_at = NOW()
WHERE package_code = 'P7K';
```

After modifications, freeze at V4.

---

# 7. MG — View Lineage Registry

## 7.1 Purpose

Documents all dependencies between MA/RF/MG objects.
Enables safe DROP/RECREATE order and CASCADE risk identification.

## 7.2 Objects at CASCADE HIGH risk

| At-risk object | Type | Dependents |
|----------------|------|-----------|
| ma.v_isa_executive_priority_portfolio | VIEW | 7 objects |
| ma.mv_isa_executive_master_board | MATERIALIZED VIEW | 2 views |
| ma.v_isa_decision_country_year | VIEW | 2 objects |
| ma.v_isa_executive_master_board | VIEW | 1 view |
| ma.v_isa_intervention_decision_matrix | VIEW | 1 view |
| ma.v_p7k_executive_source | VIEW | 1 view |
| rf.isa_executive_cost_model | TABLE | 1 view |

**Always query `mg.v_lineage_cascade_risk` before any DROP.**

## 7.3 Safe refresh order

| refresh_order | Object | Type |
|---------------|--------|------|
| 1 | rf.isa_executive_cost_model | TABLE |
| 2 | mg.isa_model_governance_policy | TABLE |
| 3 | mg.v_cost_model_review_due | VIEW |
| 5 | rf.trg_cost_model_audit | TRIGGER |
| 10 | ma.v_p7k_executive_source | VIEW |
| 20 | ma.v_isa_executive_priority_portfolio | VIEW |
| 30 | ma.mv_isa_executive_master_board | MATERIALIZED VIEW |
| 40 | ma.v_isa_executive_* (7 views) | VIEW |
| 50 | ma.v_isa_predictive_readiness_registry | VIEW |

---

# 8. Materialized View — mv_isa_executive_master_board V3

## 8.1 Key metrics at freeze

| Metric | Value |
|--------|-------|
| Total rows | 8,091 |
| Countries | 54 |
| Years | 2010–2024 |
| Pillars | 10 |
| EXECUTIVE_PRIORITY | 728 |
| EXECUTIVE_PROGRAMME | 5,716 |
| EXECUTIVE_MONITOR | 1,647 |
| EXEC_BLOCKED_REVIEW | 8,091 |
| COST_MODEL_PROVISIONAL | 8,091 |
| REVIEW_ON_TRACK | 8,091 |
| avg_predictive_gap | 0.340 |
| min_predictive_gap | 0.050 (PRES) |

## 8.2 Predictive gap by pillar

| Pillar | avg_gap | min_gap | Convergence |
|--------|---------|---------|-------------|
| PRES | 0.247 | 0.050 | Fastest |
| PMON | 0.294 | 0.055 | Fast |
| PNUM | 0.285 | 0.069 | Fast |
| PTRA | 0.325 | 0.109 | Moderate |
| PHUM | 0.370 | 0.162 | Slow |
| PGEO | — | — | Slowest (no READY) |

PRES has the lowest min_gap (0.050) — at least one intervention is 5 points from the predictive threshold.

---

# 9. Restored Views

Three views were dropped by CASCADE during V3 installation and restored with corrections.

| View | Change |
|------|--------|
| `ma.v_isa_executive_cost_projection` | Now reads from MV directly — no longer joins rf.isa_executive_cost_model |
| `ma.v_isa_executive_master_board` | Adds `predictive_execution_status`, `predictive_gap_score`, `systemic_cascade_score` |
| `ma.v_isa_predictive_readiness_registry` | Adds `avg_predictive_gap`, `min_predictive_gap`, `nb_predictive_caution`, `nb_predictive_blocked` |

---

# 10. Revision Procedure

## When review_status = OVERDUE

```sql
-- 1. Identify rows to revise
SELECT * FROM mg.v_cost_model_review_due
WHERE review_status = 'OVERDUE';

-- 2. Update the value (trigger logs automatically)
UPDATE rf.isa_executive_cost_model
SET
    execution_maturity_score      = <new_value>,
    calibration_uncertainty_score = <new_uncertainty>,
    calibration_source            = '<new_source>',
    calibration_status            = 'PROVISIONAL',
    calibration_date              = CURRENT_DATE,
    calibration_review_due_date   = CURRENT_DATE + INTERVAL '12 months',
    calibration_version           = 'V4'
WHERE intervention_family_code = '<family>'
  AND pillar_code               = '<pillar>';

-- 3. Refresh the MV
REFRESH MATERIALIZED VIEW ma.mv_isa_executive_master_board;
```

## Promoting PROVISIONAL → VALIDATED

Requirements:
- Primary source verified (EXPERT or LITERATURE)
- `calibration_uncertainty_score` ≤ 0.30
- Revision documented in `calibration_source`

---

# 11. Execution Scripts

| Script | Purpose |
|--------|---------|
| `db/run/run_p7k_executive_governance.ps1` | Install P7K V1 |
| `db/run/run_p7k_finalize.ps1` | Finalize P7K V1 |
| `db/run/run_p7k_cost_model_v3.ps1` | Install cost model V3 |
| `db/run/run_p7k_views_restore_v3.ps1` | Restore cascaded views |
| `db/run/run_mg_freeze_lineage_v1.ps1` | Freeze P7K V3 + MG lineage |
| `db/run/test_p7k_dry_run.ps1` | Full P7K dry run |
| `db/run/test_p7k_cost_model_v3_dry_run.ps1` | Cost model V3 dry run |

---

# 12. Transition to P7Z

P7K V3 was designed as a deliberate prerequisite for P7Z.

| P7K V3 output | P7Z input |
|---------------|-----------|
| `predictive_gap_score` | Convergence target variable |
| `calibration_uncertainty_score` | Probability confidence weighting |
| `execution_maturity_score` | Eligibility threshold |
| `predictive_execution_status` | Initial classification |
| `sovereign_execution_pressure` | Systemic fragility base |
| `mg.isa_package_freeze_registry` | Immutable baseline reference |
| `mg.isa_view_lineage_registry` | Dependency graph for safe recalculation |

P7Z Phase 1 snapshot baseline: `rf.isa_p7z_baseline_registry` — 8,091 rows, 54 countries, captured at P7K V3 freeze.

P7Z Phase 2 produces: `ma.mv_isa_p7z_execution_probability`, `ma.v_isa_p7z_convergence_engine`, `ma.v_isa_p7z_cascade_propagation`, `ma.v_isa_p7z_fragility_engine`.

---

# 13. Audit Status

All checks passed at freeze.

| Check | Status |
|-------|--------|
| null_pressure | 0 |
| null_predictive_status | 0 |
| out_of_bounds_scores | 0 |
| uncalibrated_rows | 0 |
| invalid_review_due_date | 0 |
| governance_policy_status | OK (3 rows) |
| trigger_installed | OK |
| freeze_registry | FROZEN |
| lineage_rows | 22 |
| high_risk_objects | 7 |
| p7k_cost_model_v3_audit_status | AUDIT_OK |
