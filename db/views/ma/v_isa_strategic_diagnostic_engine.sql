-- ============================================================
-- OSA / ISA — P7F
-- View: ma.v_isa_strategic_diagnostic_engine
-- Purpose: strategic diagnostic signals from observed P7E + SWOT computed.
-- Doctrine: diagnosis only. No forecast, no simulation, no premium trigger.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_strategic_diagnostic_engine AS
WITH swot_agg AS (
    SELECT
        country_iso3,
        year,
        pillar_code,
        ROUND(AVG(swot_value) FILTER (WHERE swot_type='WKN'), 3) AS weakness_score,
        ROUND(AVG(swot_value) FILTER (WHERE swot_type='THR'), 3) AS threat_score,
        ROUND(AVG(swot_value) FILTER (WHERE swot_type='STR'), 3) AS strength_score,
        ROUND(AVG(swot_value) FILTER (WHERE swot_type='OPP'), 3) AS opportunity_score,
        COUNT(*)::INTEGER AS nb_swot_indicators,
        COUNT(*) FILTER (WHERE swot_type='WKN')::INTEGER AS nb_wkn_indicators,
        COUNT(*) FILTER (WHERE swot_type='THR')::INTEGER AS nb_thr_indicators,
        COUNT(*) FILTER (WHERE swot_type='STR')::INTEGER AS nb_str_indicators,
        COUNT(*) FILTER (WHERE swot_type='OPP')::INTEGER AS nb_opp_indicators,
        ROUND(AVG(swot_confidence), 3) AS avg_swot_confidence
    FROM ma.v_p7f_computed_swot_source
    WHERE swot_type IN ('WKN','THR','STR','OPP')
      AND compatibility_status = 'P7F_COMPAT_OK'
    GROUP BY country_iso3, year, pillar_code
), base AS (
    SELECT
        o.country_iso3,
        o.year,
        o.pillar_code,
        o.publication_status,
        o.publication_decision,
        o.isa_observed_score,
        o.sovereignty_observed_score,
        o.vulnerability_observed_score,
        o.resilience_observed_score,
        o.data_completeness,
        o.observation_confidence,
        COALESCE(s.weakness_score, 0)::NUMERIC AS weakness_score,
        COALESCE(s.threat_score, 0)::NUMERIC AS threat_score,
        COALESCE(s.strength_score, 0)::NUMERIC AS strength_score,
        COALESCE(s.opportunity_score, 0)::NUMERIC AS opportunity_score,
        COALESCE(s.nb_swot_indicators, 0)::INTEGER AS nb_swot_indicators,
        COALESCE(s.nb_wkn_indicators, 0)::INTEGER AS nb_wkn_indicators,
        COALESCE(s.nb_thr_indicators, 0)::INTEGER AS nb_thr_indicators,
        COALESCE(s.nb_str_indicators, 0)::INTEGER AS nb_str_indicators,
        COALESCE(s.nb_opp_indicators, 0)::INTEGER AS nb_opp_indicators,
        COALESCE(s.avg_swot_confidence, 0)::NUMERIC AS avg_swot_confidence
    FROM ma.v_p7f_observed_pillar_source o
    LEFT JOIN swot_agg s
      ON s.country_iso3 = o.country_iso3
     AND s.year = o.year
     AND s.pillar_code = o.pillar_code
), scored AS (
    SELECT
        b.*,
        ROUND(GREATEST(0::NUMERIC, LEAST(1::NUMERIC,
            (b.weakness_score * 0.45)
          + (b.threat_score * 0.35)
          + (LEAST(1::NUMERIC, b.vulnerability_observed_score) * 0.20)
        )), 3) AS strategic_risk_score,
        ROUND(GREATEST(0::NUMERIC, LEAST(1::NUMERIC,
            (b.strength_score * 0.40)
          + (b.opportunity_score * 0.35)
          + (LEAST(1::NUMERIC, b.resilience_observed_score) * 0.25)
        )), 3) AS strategic_upside_score,
        CASE
            WHEN b.nb_wkn_indicators > 0 AND b.nb_thr_indicators > 0 AND b.nb_str_indicators > 0 AND b.nb_opp_indicators > 0 THEN 'FULL_SWOT_AVAILABLE'
            WHEN b.nb_wkn_indicators > 0 AND b.nb_thr_indicators > 0 THEN 'WKN_THR_AVAILABLE'
            WHEN b.nb_wkn_indicators > 0 THEN 'WKN_AVAILABLE'
            WHEN b.nb_thr_indicators > 0 THEN 'THR_AVAILABLE'
            WHEN b.nb_swot_indicators > 0 THEN 'PARTIAL_SWOT_AVAILABLE'
            ELSE 'NO_COMPUTED_SWOT_ATTACHED'
        END AS swot_data_status
    FROM base b
), finalized AS (
    SELECT
        s.*,
        CASE
            WHEN s.threat_score >= 0.65 OR s.strategic_risk_score >= 0.70 THEN 'THREAT_TO_MITIGATE'
            WHEN s.weakness_score >= 0.60 OR s.isa_observed_score < 0.45 THEN 'WEAKNESS_TO_FIX'
            WHEN s.opportunity_score >= 0.65 AND s.strategic_upside_score >= 0.60 THEN 'OPPORTUNITY_TO_ACCELERATE'
            WHEN s.strength_score >= 0.65 OR s.isa_observed_score >= 0.75 THEN 'STRENGTH_TO_SCALE'
            ELSE 'OBSERVATION_TO_MONITOR'
        END AS strategic_diagnostic_role,
        CASE
            WHEN s.strategic_risk_score >= 0.75 THEN 'DIAGNOSTIC_ATTENTION_CRITICAL'
            WHEN s.strategic_risk_score >= 0.60 THEN 'DIAGNOSTIC_ATTENTION_HIGH'
            WHEN s.strategic_upside_score >= 0.65 THEN 'DIAGNOSTIC_UPSIDE_HIGH'
            WHEN s.strategic_risk_score >= 0.45 THEN 'DIAGNOSTIC_ATTENTION_MODERATE'
            ELSE 'DIAGNOSTIC_MONITORING'
        END AS strategic_attention_class,
        ROUND(GREATEST(0::NUMERIC, LEAST(1::NUMERIC,
            CASE
                WHEN s.threat_score >= 0.65 OR s.strategic_risk_score >= 0.70 THEN s.strategic_risk_score
                WHEN s.weakness_score >= 0.60 OR s.isa_observed_score < 0.45 THEN GREATEST(s.weakness_score, 1 - LEAST(1::NUMERIC, s.isa_observed_score))
                WHEN s.opportunity_score >= 0.65 AND s.strategic_upside_score >= 0.60 THEN s.strategic_upside_score
                WHEN s.strength_score >= 0.65 OR s.isa_observed_score >= 0.75 THEN GREATEST(s.strength_score, LEAST(1::NUMERIC, s.isa_observed_score))
                ELSE (s.strategic_risk_score + s.strategic_upside_score) / 2
            END
        )), 3) AS diagnostic_priority_score
    FROM scored s
)
SELECT
    f.country_iso3,
    f.year,
    f.pillar_code,
    f.publication_status,
    f.publication_decision,
    f.isa_observed_score,
    f.sovereignty_observed_score,
    f.vulnerability_observed_score,
    f.resilience_observed_score,
    f.data_completeness,
    f.observation_confidence,
    f.weakness_score,
    f.threat_score,
    f.strength_score,
    f.opportunity_score,
    f.strategic_risk_score,
    f.strategic_upside_score,
    f.nb_swot_indicators,
    f.nb_wkn_indicators,
    f.nb_thr_indicators,
    f.nb_str_indicators,
    f.nb_opp_indicators,
    f.avg_swot_confidence,
    f.swot_data_status,
    f.strategic_diagnostic_role,
    f.strategic_attention_class,
    f.diagnostic_priority_score,
    p.role_label AS strategic_diagnostic_label,
    p.open_data_allowed,
    p.predictive_required,
    p.premium_allowed,
    p.notes AS diagnostic_policy_notes
FROM finalized f
LEFT JOIN rf.isa_strategic_diagnostic_policy p
  ON p.diagnostic_role = f.strategic_diagnostic_role;
