-- ============================================================
-- OSA / ISA — P7F
-- View: ma.v_p7f_observed_pillar_source
-- Purpose: stable P7E observed pillar source.
-- Depends: ma.v_isa_observed_scores_by_pillar confirmed columns.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7f_observed_pillar_source AS
SELECT
    country_iso3::TEXT AS country_iso3,
    year::INTEGER AS year,
    pillar_code::TEXT AS pillar_code,
    publication_status::TEXT AS publication_status,
    publication_decision::TEXT AS publication_decision,
    GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC, COALESCE(isa_observed_score, 0)::NUMERIC)) AS isa_observed_score,
    GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC, COALESCE(sovereignty_observed_score, 0)::NUMERIC)) AS sovereignty_observed_score,
    GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC, COALESCE(vulnerability_observed_score, 0)::NUMERIC)) AS vulnerability_observed_score,
    GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC, COALESCE(resilience_observed_score, 0)::NUMERIC)) AS resilience_observed_score,
    GREATEST(0::NUMERIC, LEAST(1::NUMERIC, COALESCE(data_completeness, 0)::NUMERIC)) AS data_completeness,
    GREATEST(0::NUMERIC, LEAST(1::NUMERIC, COALESCE(avg_observation_confidence, 0.65)::NUMERIC)) AS observation_confidence
FROM ma.v_isa_observed_scores_by_pillar;
