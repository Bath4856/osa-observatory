CREATE OR REPLACE VIEW ma.v_isa_executive_cost_projection AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    p.intervention_family_code,
    p.intervention_family_label,
    p.executive_cost_score,
    p.implementation_complexity,
    p.sovereign_dependency_score,
    p.execution_maturity_score,
    p.execution_horizon_years,
    p.sovereign_execution_pressure
FROM ma.mv_isa_executive_master_board p;
