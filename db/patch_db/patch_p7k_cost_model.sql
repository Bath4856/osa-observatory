BEGIN;

CREATE TABLE IF NOT EXISTS rf.isa_executive_cost_model (
    intervention_family_code          TEXT PRIMARY KEY,
    executive_cost_score              NUMERIC(6,3),
    implementation_complexity         NUMERIC(6,3),
    sovereign_dependency_score        NUMERIC(6,3),
    execution_maturity_score          NUMERIC(6,3),
    execution_horizon_years           INTEGER,
    created_at                        TIMESTAMP DEFAULT NOW()
);

TRUNCATE TABLE rf.isa_executive_cost_model;

INSERT INTO rf.isa_executive_cost_model
SELECT
    intervention_family_code,
    budget_intensity_score,
    governance_complexity,
    sovereign_dependency_score,
    (1 - governance_complexity + 0.30),
    implementation_horizon_years,
    NOW()
FROM rf.isa_intervention_family_registry;

COMMIT;