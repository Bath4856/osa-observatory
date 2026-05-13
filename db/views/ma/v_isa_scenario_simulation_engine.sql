CREATE OR REPLACE VIEW ma.v_isa_scenario_simulation_engine AS
WITH src AS (
    SELECT * FROM ma.v_p7h_scenario_source
), pol AS (
    SELECT * FROM ma.v_isa_scenario_policy_engine
), base AS (
    SELECT
        s.country_iso3,
        s.year,
        s.pillar_code,
        p.scenario_code,
        p.scenario_label,
        p.scenario_family,
        s.publication_status,
        s.publication_decision,
        s.isa_observed_score,
        s.sovereignty_observed_score,
        s.vulnerability_observed_score,
        s.resilience_observed_score,
        s.data_completeness,
        s.observation_confidence,
        s.weakness_score,
        s.threat_score,
        s.strength_score,
        s.opportunity_score,
        s.strategic_risk_score,
        s.strategic_upside_score,
        s.diagnostic_priority_score,
        s.strategic_diagnostic_role,
        s.strategic_attention_class,
        s.forecast_policy_code,
        s.forecast_trend_status,
        s.forecast_blocking_reason,
        s.forecast_trend_class,
        s.isa_trend_slope,
        s.isa_volatility,
        s.avg_forecast_readiness_score,
        s.avg_ml_readiness_score,
        p.intervention_intensity,
        p.risk_adjustment_factor,
        p.confidence_adjustment_factor,
        p.max_positive_delta,
        p.max_negative_delta,
        p.include_in_public_simulation,
        p.isa_elasticity,
        p.sovereignty_elasticity,
        p.vulnerability_elasticity,
        p.resilience_elasticity,
        p.simulation_floor,
        p.simulation_ceiling,
        CASE
            WHEN s.strategic_diagnostic_role = 'WEAKNESS_TO_FIX' THEN s.weakness_score
            WHEN s.strategic_diagnostic_role = 'THREAT_TO_MITIGATE' THEN s.threat_score
            WHEN s.strategic_diagnostic_role = 'STRENGTH_TO_SCALE' THEN s.strength_score
            WHEN s.strategic_diagnostic_role = 'OPPORTUNITY_TO_ACCELERATE' THEN s.opportunity_score
            ELSE GREATEST(s.diagnostic_priority_score, s.strategic_risk_score, s.strategic_upside_score)
        END::NUMERIC AS leverage_score
    FROM src s
    JOIN pol p ON p.pillar_code = s.pillar_code
), calc AS (
    SELECT
        *,
        LEAST(1, GREATEST(0,
            (observation_confidence * 0.45)
          + (data_completeness * 0.25)
          + (CASE
                WHEN forecast_blocking_reason = 'FORECAST_ALLOWED' THEN 0.20
                WHEN forecast_blocking_reason = 'VOLATILITY_WARNING' THEN 0.12
                WHEN forecast_blocking_reason = 'LOW_CONFIDENCE' THEN 0.05
                ELSE 0.03
             END)
          + (avg_forecast_readiness_score * 0.10)
        ))::NUMERIC AS simulation_confidence_raw,
        CASE
            WHEN forecast_blocking_reason = 'LOW_CONFIDENCE' THEN 0.65
            WHEN forecast_blocking_reason = 'VOLATILITY_WARNING' THEN 0.85
            WHEN forecast_blocking_reason = 'FORECAST_ALLOWED' THEN 1.00
            ELSE 0.70
        END::NUMERIC AS forecast_reliability_factor
    FROM base
), deltas AS (
    SELECT
        *,
        CASE
            WHEN scenario_code = 'BASELINE' THEN 0::NUMERIC
            WHEN scenario_code = 'STRESS' THEN
                GREATEST(-max_negative_delta,
                    LEAST(0,
                        intervention_intensity * risk_adjustment_factor * (0.50 + strategic_risk_score) * isa_elasticity
                    )
                )
            ELSE
                LEAST(max_positive_delta,
                    GREATEST(0,
                        intervention_intensity
                      * risk_adjustment_factor
                      * forecast_reliability_factor
                      * (0.40 + leverage_score)
                      * isa_elasticity
                    )
                )
        END::NUMERIC AS simulated_isa_delta_raw,
        CASE
            WHEN scenario_code = 'BASELINE' THEN 0::NUMERIC
            WHEN scenario_code = 'STRESS' THEN
                GREATEST(-max_negative_delta,
                    intervention_intensity * risk_adjustment_factor * (0.50 + strategic_risk_score) * sovereignty_elasticity
                )
            ELSE
                LEAST(max_positive_delta,
                    intervention_intensity * risk_adjustment_factor * forecast_reliability_factor * (0.40 + leverage_score) * sovereignty_elasticity
                )
        END::NUMERIC AS simulated_sovereignty_delta_raw,
        CASE
            WHEN scenario_code = 'BASELINE' THEN 0::NUMERIC
            WHEN scenario_code = 'STRESS' THEN
                LEAST(max_negative_delta,
                    ABS(intervention_intensity) * risk_adjustment_factor * (0.50 + strategic_risk_score) * vulnerability_elasticity
                )
            ELSE
                GREATEST(-max_negative_delta,
                    -1 * intervention_intensity * risk_adjustment_factor * forecast_reliability_factor * (0.40 + leverage_score) * vulnerability_elasticity
                )
        END::NUMERIC AS simulated_vulnerability_delta_raw,
        CASE
            WHEN scenario_code = 'BASELINE' THEN 0::NUMERIC
            WHEN scenario_code = 'STRESS' THEN
                GREATEST(-max_negative_delta,
                    intervention_intensity * risk_adjustment_factor * (0.50 + strategic_risk_score) * resilience_elasticity
                )
            ELSE
                LEAST(max_positive_delta,
                    intervention_intensity * risk_adjustment_factor * forecast_reliability_factor * (0.40 + leverage_score) * resilience_elasticity
                )
        END::NUMERIC AS simulated_resilience_delta_raw
    FROM calc
)
SELECT
    country_iso3,
    year,
    pillar_code,
    scenario_code,
    scenario_label,
    scenario_family,
    publication_status,
    publication_decision,
    strategic_diagnostic_role,
    strategic_attention_class,
    forecast_policy_code,
    forecast_trend_status,
    forecast_blocking_reason,
    ROUND(isa_observed_score, 3)::NUMERIC(8,3) AS isa_observed_score,
    ROUND(sovereignty_observed_score, 3)::NUMERIC(8,3) AS sovereignty_observed_score,
    ROUND(vulnerability_observed_score, 3)::NUMERIC(8,3) AS vulnerability_observed_score,
    ROUND(resilience_observed_score, 3)::NUMERIC(8,3) AS resilience_observed_score,
    ROUND(leverage_score, 3)::NUMERIC(8,3) AS leverage_score,
    ROUND(simulation_confidence_raw * confidence_adjustment_factor, 3)::NUMERIC(8,3) AS simulation_confidence,
    ROUND(GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_isa_delta_raw)), 3)::NUMERIC(8,3) AS simulated_isa_delta,
    ROUND(GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_sovereignty_delta_raw)), 3)::NUMERIC(8,3) AS simulated_sovereignty_delta,
    ROUND(GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_vulnerability_delta_raw)), 3)::NUMERIC(8,3) AS simulated_vulnerability_delta,
    ROUND(GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_resilience_delta_raw)), 3)::NUMERIC(8,3) AS simulated_resilience_delta,
    ROUND(GREATEST(0, LEAST(1.5, isa_observed_score + GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_isa_delta_raw)))), 3)::NUMERIC(8,3) AS simulated_isa_score,
    ROUND(GREATEST(0, LEAST(1.5, sovereignty_observed_score + GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_sovereignty_delta_raw)))), 3)::NUMERIC(8,3) AS simulated_sovereignty_score,
    ROUND(GREATEST(0, LEAST(1.5, vulnerability_observed_score + GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_vulnerability_delta_raw)))), 3)::NUMERIC(8,3) AS simulated_vulnerability_score,
    ROUND(GREATEST(0, LEAST(1.5, resilience_observed_score + GREATEST(simulation_floor, LEAST(simulation_ceiling, simulated_resilience_delta_raw)))), 3)::NUMERIC(8,3) AS simulated_resilience_score,
    CASE
        WHEN simulation_confidence_raw * confidence_adjustment_factor >= 0.700 THEN 'SIMULATION_CONFIDENCE_STRONG'
        WHEN simulation_confidence_raw * confidence_adjustment_factor >= 0.550 THEN 'SIMULATION_CONFIDENCE_CONTROLLED'
        WHEN simulation_confidence_raw * confidence_adjustment_factor >= 0.400 THEN 'SIMULATION_CONFIDENCE_INDICATIVE'
        ELSE 'SIMULATION_REVIEW_REQUIRED'
    END::TEXT AS simulation_confidence_class,
    CASE
        WHEN scenario_code = 'BASELINE' THEN 'BASELINE_REFERENCE'
        WHEN scenario_code = 'STRESS' THEN 'STRESS_TEST_ONLY'
        WHEN forecast_blocking_reason = 'LOW_CONFIDENCE' THEN 'SIMULATION_CONTEXTUAL_LOW_CONFIDENCE'
        WHEN forecast_blocking_reason = 'VOLATILITY_WARNING' THEN 'SIMULATION_WITH_VOLATILITY_WARNING'
        WHEN simulation_confidence_raw * confidence_adjustment_factor >= 0.550 THEN 'SIMULATION_USABLE_FOR_POLICY_DISCUSSION'
        ELSE 'SIMULATION_INDICATIVE_REVIEW_REQUIRED'
    END::TEXT AS simulation_decision,
    CASE
        WHEN include_in_public_simulation IS TRUE AND scenario_code <> 'STRESS' THEN 'OPEN_DATA_SIMULATION_CANDIDATE'
        WHEN scenario_code = 'STRESS' THEN 'INTERNAL_RISK_SIMULATION'
        ELSE 'EXPERT_REVIEW_SIMULATION'
    END::TEXT AS simulation_scope
FROM deltas;
