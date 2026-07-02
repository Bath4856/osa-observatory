-- ============================================================
-- Sprint 28 Lot B -- weakness_score_raw dans ma.v_p7i_risk_source
-- GAF finding #24 WKN_PENV_NULL_MASKED_SDN_2024 (ORIENTED)
-- 25 juin 2026
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint28_lot_b_weakness_score_raw.sql
-- ============================================================
-- OBJET :
--   Exposition de weakness_score_raw dans ma.v_p7i_risk_source.
--   COALESCE(d.weakness_score, 0) masque les vrais NULL en
--   produisant weakness_score=0.000 quand la donnee est absente.
--   weakness_score_raw expose la valeur brute avant COALESCE,
--   permettant de distinguer zero reel vs donnee manquante.
--   Colonne ajoutee en fin de liste -- non destructif pour les
--   vues dependantes (v_isa_early_warning_engine,
--   v_p7i_amar_atrocity_precursor_engine,
--   v_p7i_amar_geneco_engine, v_p7j_recommendation_engine).
-- ============================================================

BEGIN;

CREATE OR REPLACE VIEW ma.v_p7i_risk_source AS
WITH scenario_agg AS (
    SELECT v_isa_scenario_simulation_engine.country_iso3,
           v_isa_scenario_simulation_engine.year,
           v_isa_scenario_simulation_engine.pillar_code,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'CENTRAL'::text    THEN v_isa_scenario_simulation_engine.simulated_isa_delta    ELSE NULL::numeric END) AS central_isa_delta,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'AMBITIOUS'::text  THEN v_isa_scenario_simulation_engine.simulated_isa_delta    ELSE NULL::numeric END) AS ambitious_isa_delta,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'STRESS'::text     THEN v_isa_scenario_simulation_engine.simulated_isa_delta    ELSE NULL::numeric END) AS stress_isa_delta,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'CENTRAL'::text    THEN v_isa_scenario_simulation_engine.simulation_confidence  ELSE NULL::numeric END) AS central_simulation_confidence,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'AMBITIOUS'::text  THEN v_isa_scenario_simulation_engine.simulation_confidence  ELSE NULL::numeric END) AS ambitious_simulation_confidence,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'STRESS'::text     THEN v_isa_scenario_simulation_engine.simulation_confidence  ELSE NULL::numeric END) AS stress_simulation_confidence,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'CENTRAL'::text    THEN v_isa_scenario_simulation_engine.simulation_decision    ELSE NULL::text    END) AS central_simulation_decision,
           max(CASE WHEN v_isa_scenario_simulation_engine.scenario_code::text = 'STRESS'::text     THEN v_isa_scenario_simulation_engine.simulation_decision    ELSE NULL::text    END) AS stress_simulation_decision
    FROM ma.v_isa_scenario_simulation_engine
    GROUP BY v_isa_scenario_simulation_engine.country_iso3,
             v_isa_scenario_simulation_engine.year,
             v_isa_scenario_simulation_engine.pillar_code
)
SELECT
    d.country_iso3,
    d.year,
    d.pillar_code,
    d.publication_status,
    d.publication_decision,
    COALESCE(d.isa_observed_score,            0::numeric) AS isa_observed_score,
    COALESCE(d.sovereignty_observed_score,    0::numeric) AS sovereignty_observed_score,
    COALESCE(d.vulnerability_observed_score,  0::numeric) AS vulnerability_observed_score,
    COALESCE(d.resilience_observed_score,     0::numeric) AS resilience_observed_score,
    COALESCE(d.data_completeness,             0::numeric) AS data_completeness,
    COALESCE(d.observation_confidence,        0::numeric) AS observation_confidence,
    COALESCE(d.weakness_score,                0::numeric) AS weakness_score,
    COALESCE(d.threat_score,                  0::numeric) AS threat_score,
    COALESCE(d.strength_score,                0::numeric) AS strength_score,
    COALESCE(d.opportunity_score,             0::numeric) AS opportunity_score,
    COALESCE(d.strategic_risk_score,          0::numeric) AS strategic_risk_score,
    COALESCE(d.strategic_upside_score,        0::numeric) AS strategic_upside_score,
    COALESCE(d.diagnostic_priority_score,     0::numeric) AS diagnostic_priority_score,
    d.strategic_diagnostic_role,
    d.strategic_attention_class,
    d.swot_data_status,
    COALESCE(t.history_years,                 0)          AS history_years,
    COALESCE(t.avg_observation_confidence,    0::numeric) AS forecast_observation_confidence,
    COALESCE(t.isa_trend_slope,               0::numeric) AS isa_trend_slope,
    COALESCE(t.isa_volatility,                0::numeric) AS isa_volatility,
    COALESCE(t.forecast_policy_code,          'NO_FORECAST'::text)              AS forecast_policy_code,
    COALESCE(t.forecast_trend_class,          'UNKNOWN'::text)                  AS forecast_trend_class,
    COALESCE(t.forecast_trend_status,         'FORECAST_REVIEW_REQUIRED'::text) AS forecast_trend_status,
    COALESCE(t.forecast_blocking_reason,      'FORECAST_REVIEW_REQUIRED'::text) AS forecast_blocking_reason,
    COALESCE(s.central_isa_delta,             0::numeric) AS central_isa_delta,
    COALESCE(s.ambitious_isa_delta,           0::numeric) AS ambitious_isa_delta,
    COALESCE(s.stress_isa_delta,              0::numeric) AS stress_isa_delta,
    COALESCE(s.central_simulation_confidence, 0::numeric) AS central_simulation_confidence,
    COALESCE(s.ambitious_simulation_confidence, 0::numeric) AS ambitious_simulation_confidence,
    COALESCE(s.stress_simulation_confidence,  0::numeric) AS stress_simulation_confidence,
    COALESCE(s.central_simulation_decision,   'SIMULATION_REVIEW_REQUIRED'::text) AS central_simulation_decision,
    COALESCE(s.stress_simulation_decision,    'STRESS_REVIEW_REQUIRED'::text)     AS stress_simulation_decision,
    -- GAF finding #24 WKN_PENV_NULL_MASKED_SDN_2024 :
    -- valeur brute avant COALESCE -- NULL = donnee absente, 0.000 = zero observe
    d.weakness_score AS weakness_score_raw
FROM ma.v_isa_strategic_diagnostic_engine d
LEFT JOIN ma.v_isa_forecast_trend_engine t
    ON t.country_iso3 = d.country_iso3
    AND t.pillar_code = d.pillar_code
LEFT JOIN scenario_agg s
    ON s.country_iso3 = d.country_iso3
    AND s.year = d.year
    AND s.pillar_code = d.pillar_code;

-- Verification
SELECT
    COUNT(*)                                                                    AS total,
    COUNT(weakness_score_raw)                                                   AS non_null_raw,
    COUNT(*) - COUNT(weakness_score_raw)                                        AS null_raw,
    COUNT(CASE WHEN weakness_score = 0 AND weakness_score_raw IS NULL THEN 1 END) AS coalesce_masking_detected
FROM ma.v_p7i_risk_source
WHERE year = 2024;

COMMIT;
