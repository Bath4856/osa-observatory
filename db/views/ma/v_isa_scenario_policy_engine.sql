CREATE OR REPLACE VIEW ma.v_isa_scenario_policy_engine AS
SELECT
    sp.scenario_code,
    sp.scenario_label,
    sp.scenario_family,
    sp.intervention_intensity,
    sp.risk_adjustment_factor,
    sp.confidence_adjustment_factor,
    sp.max_positive_delta,
    sp.max_negative_delta,
    sp.include_in_public_simulation,
    sp.simulation_notes,
    pe.pillar_code,
    pe.pillar_label,
    pe.isa_elasticity,
    pe.sovereignty_elasticity,
    pe.vulnerability_elasticity,
    pe.resilience_elasticity,
    pe.simulation_floor,
    pe.simulation_ceiling,
    pe.notes AS pillar_elasticity_notes
FROM rf.isa_scenario_policy sp
CROSS JOIN rf.isa_scenario_pillar_elasticity pe;
