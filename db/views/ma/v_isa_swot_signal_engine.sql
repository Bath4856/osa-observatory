-- ============================================================
-- OSA / ISA — P7X
-- View: ma.v_isa_swot_signal_engine
-- Purpose: Convert observed P7E scores and computed WKN/THR/STR/OPP
--          into stable SWOT signals. Does not alter ISA scores.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_swot_signal_engine AS
WITH observed AS (
    SELECT
        country_iso3,
        year,
        pillar_code,
        isa_observed_score,
        sovereignty_observed_score,
        vulnerability_observed_score,
        resilience_observed_score,
        data_completeness,
        observation_confidence,
        publication_status,
        publication_decision
    FROM ma.v_p7x_observed_pillar_source
),
swot AS (
    SELECT
        country_iso3,
        year,
        pillar_code,
        swot_type,
        COUNT(*) AS nb_swot_indicators,
        ROUND(AVG(GREATEST(0, LEAST(1.5, COALESCE(swot_value,0))))::numeric,3) AS avg_swot_value,
        MAX(GREATEST(0, LEAST(1.5, COALESCE(swot_value,0)))) AS max_swot_value
    FROM ma.v_p7x_computed_swot_source
    WHERE swot_type IN ('WKN','THR','STR','OPP')
    GROUP BY country_iso3, year, pillar_code, swot_type
),
pivoted AS (
    SELECT
        o.*,
        COALESCE(MAX(CASE WHEN s.swot_type='WKN' THEN s.avg_swot_value END), 0)::numeric AS weakness_score,
        COALESCE(MAX(CASE WHEN s.swot_type='THR' THEN s.avg_swot_value END), 0)::numeric AS threat_score,
        COALESCE(MAX(CASE WHEN s.swot_type='STR' THEN s.avg_swot_value END), 0)::numeric AS strength_score,
        COALESCE(MAX(CASE WHEN s.swot_type='OPP' THEN s.avg_swot_value END), 0)::numeric AS opportunity_score,
        COALESCE(SUM(s.nb_swot_indicators), 0)::int AS nb_swot_indicators,
        COALESCE(SUM(CASE WHEN s.swot_type='WKN' THEN s.nb_swot_indicators ELSE 0 END),0)::int AS nb_wkn_indicators,
        COALESCE(SUM(CASE WHEN s.swot_type='THR' THEN s.nb_swot_indicators ELSE 0 END),0)::int AS nb_thr_indicators,
        COALESCE(SUM(CASE WHEN s.swot_type='STR' THEN s.nb_swot_indicators ELSE 0 END),0)::int AS nb_str_indicators,
        COALESCE(SUM(CASE WHEN s.swot_type='OPP' THEN s.nb_swot_indicators ELSE 0 END),0)::int AS nb_opp_indicators
    FROM observed o
    LEFT JOIN swot s
      ON s.country_iso3 = o.country_iso3
     AND s.year = o.year
     AND s.pillar_code = o.pillar_code
    GROUP BY
        o.country_iso3, o.year, o.pillar_code,
        o.isa_observed_score, o.sovereignty_observed_score,
        o.vulnerability_observed_score, o.resilience_observed_score,
        o.data_completeness, o.observation_confidence,
        o.publication_status, o.publication_decision
),
classified AS (
    SELECT
        p.*,
        ROUND((p.weakness_score * 0.35 + p.threat_score * 0.40 + p.vulnerability_observed_score * 0.25)::numeric,3) AS strategic_risk_score,
        ROUND((p.strength_score * 0.35 + p.opportunity_score * 0.35 + p.resilience_observed_score * 0.30)::numeric,3) AS strategic_upside_score,
        CASE
            WHEN p.threat_score >= 0.75 OR p.vulnerability_observed_score >= 0.85 THEN 'THREAT_TO_MITIGATE'
            WHEN p.weakness_score >= 0.65 OR p.isa_observed_score < 0.45 THEN 'WEAKNESS_TO_FIX'
            WHEN p.opportunity_score >= 0.65 THEN 'OPPORTUNITY_TO_ACCELERATE'
            WHEN p.strength_score >= 0.65 OR p.sovereignty_observed_score >= 0.75 THEN 'STRENGTH_TO_SCALE'
            ELSE 'OBSERVATION_TO_MONITOR'
        END AS swot_strategic_role,
        CASE
            WHEN p.nb_swot_indicators = 0 THEN 'NO_COMPUTED_SWOT_ATTACHED'
            WHEN p.nb_wkn_indicators > 0 AND p.nb_thr_indicators > 0 THEN 'WKN_THR_AVAILABLE'
            WHEN p.nb_wkn_indicators > 0 THEN 'WKN_AVAILABLE'
            WHEN p.nb_thr_indicators > 0 THEN 'THR_AVAILABLE'
            ELSE 'STR_OPP_OR_OTHER_AVAILABLE'
        END AS swot_data_status
    FROM pivoted p
)
SELECT
    country_iso3,
    year,
    pillar_code,
    publication_status,
    publication_decision,
    isa_observed_score,
    sovereignty_observed_score,
    vulnerability_observed_score,
    resilience_observed_score,
    data_completeness,
    observation_confidence,
    weakness_score,
    threat_score,
    strength_score,
    opportunity_score,
    strategic_risk_score,
    strategic_upside_score,
    nb_swot_indicators,
    nb_wkn_indicators,
    nb_thr_indicators,
    nb_str_indicators,
    nb_opp_indicators,
    swot_strategic_role,
    swot_data_status,
    CASE
        WHEN swot_strategic_role = 'THREAT_TO_MITIGATE' THEN 'HIGH_STRATEGIC_ATTENTION'
        WHEN swot_strategic_role = 'WEAKNESS_TO_FIX' THEN 'MEDIUM_HIGH_STRATEGIC_ATTENTION'
        WHEN swot_strategic_role = 'OPPORTUNITY_TO_ACCELERATE' THEN 'OPPORTUNITY_ATTENTION'
        WHEN swot_strategic_role = 'STRENGTH_TO_SCALE' THEN 'SCALING_ATTENTION'
        ELSE 'MONITORING_ATTENTION'
    END AS strategic_attention_class
FROM classified;
