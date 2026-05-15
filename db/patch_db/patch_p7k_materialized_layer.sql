BEGIN;

--------------------------------------------------
-- CLEAN
--------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS ma.mv_isa_executive_master_board;

DROP TABLE IF EXISTS ma.tmp_exec_master_board;

--------------------------------------------------
-- STEP 1 : BUILD TEMP TABLE
--------------------------------------------------

CREATE TABLE ma.tmp_exec_master_board AS

SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,

    p.intervention_family_code,
    p.intervention_family_label,

    p.executive_decision_class,
    p.executive_priority_score,

    p.budget_pressure_score,
    p.governance_risk_score,

    c.executive_cost_score,
    c.implementation_complexity,
    c.execution_horizon_years,

    cp.sovereign_execution_pressure,

    CASE
        WHEN cp.sovereign_execution_pressure >= 0.80
            THEN 'EXECUTIVE_CRITICAL'

        WHEN cp.sovereign_execution_pressure >= 0.65
            THEN 'EXECUTIVE_PRIORITY'

        WHEN cp.sovereign_execution_pressure >= 0.45
            THEN 'EXECUTIVE_PROGRAMME'

        ELSE 'EXECUTIVE_MONITOR'
    END AS executive_master_status,

    CASE
        WHEN p.executive_priority_score >= 0.75
             AND c.execution_maturity_score >= 0.60
            THEN TRUE
        ELSE FALSE
    END AS predictive_ready_flag,

    ROUND(
        (
            p.governance_risk_score * 0.50
            + c.sovereign_dependency_score * 0.50
        )::numeric,
        3
    ) AS systemic_cascade_score

FROM ma.v_isa_executive_priority_portfolio p

LEFT JOIN rf.isa_executive_cost_model c
ON p.intervention_family_code = c.intervention_family_code

LEFT JOIN ma.v_isa_executive_cost_projection cp
ON p.country_iso3 = cp.country_iso3
AND p.year = cp.year
AND p.intervention_family_code = cp.intervention_family_code;

COMMIT;

--------------------------------------------------
-- ANALYZE TEMP TABLE
--------------------------------------------------

ANALYZE ma.tmp_exec_master_board;

--------------------------------------------------
-- STEP 2 : CREATE MV FROM TABLE
--------------------------------------------------

CREATE MATERIALIZED VIEW ma.mv_isa_executive_master_board AS
SELECT *
FROM ma.tmp_exec_master_board;

--------------------------------------------------
-- INDEXES
--------------------------------------------------

CREATE INDEX idx_mv_exec_country
ON ma.mv_isa_executive_master_board(country_iso3);

CREATE INDEX idx_mv_exec_year
ON ma.mv_isa_executive_master_board(year);

CREATE INDEX idx_mv_exec_pillar
ON ma.mv_isa_executive_master_board(pillar_code);

CREATE INDEX idx_mv_exec_status
ON ma.mv_isa_executive_master_board(executive_master_status);

ANALYZE ma.mv_isa_executive_master_board;