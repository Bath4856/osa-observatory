-- ============================================================
-- OSA / ISA — P7E
-- View: ma.v_isa_observed_publication_readiness
-- Purpose:
--   Publication readiness summary for observed ISA scores.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_observed_publication_readiness AS
SELECT
    publication_status,
    publication_cycle,
    methodology_version,
    COUNT(DISTINCT country_iso3) AS nb_countries,
    COUNT(DISTINCT year) AS nb_years,
    COUNT(DISTINCT pillar_code) AS nb_pillars,
    COUNT(*) AS nb_country_year_pillar_rows,
    ROUND(AVG(data_completeness)::NUMERIC, 3) AS avg_data_completeness,
    ROUND(AVG(avg_observation_confidence)::NUMERIC, 3) AS avg_observation_confidence,
    ROUND(AVG(isa_observed_score)::NUMERIC, 3) AS avg_isa_observed_score,
    ROUND(AVG(sovereignty_observed_score)::NUMERIC, 3) AS avg_sovereignty_observed_score,
    ROUND(AVG(vulnerability_observed_score)::NUMERIC, 3) AS avg_vulnerability_observed_score,
    ROUND(AVG(resilience_observed_score)::NUMERIC, 3) AS avg_resilience_observed_score,
    SUM(CASE WHEN publication_decision = 'PUBLISH_OFFICIAL' THEN 1 ELSE 0 END) AS nb_publish_official,
    SUM(CASE WHEN publication_decision = 'PUBLISH_PROVISIONAL_WITH_WARNING' THEN 1 ELSE 0 END) AS nb_publish_provisional,
    SUM(CASE WHEN publication_decision = 'MONITOR_ONLY' THEN 1 ELSE 0 END) AS nb_monitor_only,
    SUM(CASE WHEN publication_decision = 'DO_NOT_PUBLISH' THEN 1 ELSE 0 END) AS nb_do_not_publish,
    CASE
        WHEN publication_status = 'OFFICIAL_CONSOLIDATED'
         AND AVG(data_completeness) >= 0.70
            THEN 'PUBLICATION_READY_OFFICIAL'
        WHEN publication_status = 'PROVISIONAL_N1'
            THEN 'PUBLICATION_READY_PROVISIONAL_WITH_WARNING'
        WHEN publication_status = 'CURRENT_YEAR_MONITORING'
            THEN 'PUBLICATION_MONITORING_ONLY'
        ELSE 'PUBLICATION_NOT_READY'
    END AS publication_readiness_status
FROM ma.v_isa_observed_scores_by_pillar
GROUP BY publication_status, publication_cycle, methodology_version;
