-- ============================================================
-- OSA / ISA
-- Recalibrage moteur pays
-- FIX type mismatch
-- ============================================================

DROP VIEW IF EXISTS ma.v_isa_early_warning_country_year CASCADE;

CREATE VIEW ma.v_isa_early_warning_country_year AS
SELECT
    country_iso3,
    year,

    COUNT(*)::integer AS nb_pillars_monitored,

    ROUND(AVG(early_warning_score), 3) AS country_early_warning_score,
    ROUND(AVG(early_warning_confidence), 3) AS country_early_warning_confidence,

    SUM(CASE WHEN sovereign_alert_level = 'RED' THEN 1 ELSE 0 END)::integer AS nb_red_alerts,
    SUM(CASE WHEN sovereign_alert_level = 'ORANGE' THEN 1 ELSE 0 END)::integer AS nb_orange_alerts,
    SUM(CASE WHEN sovereign_alert_level = 'YELLOW' THEN 1 ELSE 0 END)::integer AS nb_yellow_alerts,
    SUM(CASE WHEN sovereign_alert_level = 'GREEN' THEN 1 ELSE 0 END)::integer AS nb_green_alerts,

    ROUND(AVG(fragility_warning_score), 3) AS avg_fragility_warning_score,
    ROUND(AVG(stress_propagation_score), 3) AS avg_stress_propagation_score,

    CASE
        WHEN SUM(CASE WHEN sovereign_alert_level='RED' THEN 1 ELSE 0 END) >= 1
            THEN 'RED'

        WHEN SUM(CASE WHEN sovereign_alert_level='ORANGE' THEN 1 ELSE 0 END) >= 6
          OR AVG(early_warning_score) >= 0.500
            THEN 'ORANGE'

        WHEN SUM(CASE WHEN sovereign_alert_level='ORANGE' THEN 1 ELSE 0 END) >= 1
          OR AVG(early_warning_score) >= 0.350
            THEN 'YELLOW'

        ELSE 'GREEN'
    END AS country_sovereign_alert_level,

    CASE
        WHEN SUM(CASE WHEN sovereign_alert_level='RED' THEN 1 ELSE 0 END) >= 1
            THEN 'COUNTRY_CRITICAL_ALERT'

        WHEN SUM(CASE WHEN sovereign_alert_level='ORANGE' THEN 1 ELSE 0 END) >= 6
          OR AVG(early_warning_score) >= 0.500
            THEN 'COUNTRY_WARNING_STRATEGIC_REVIEW_REQUIRED'

        WHEN SUM(CASE WHEN sovereign_alert_level='ORANGE' THEN 1 ELSE 0 END) >= 1
          OR AVG(early_warning_score) >= 0.350
            THEN 'COUNTRY_ATTENTION_MONITOR'

        ELSE 'COUNTRY_STABLE'
    END AS country_early_warning_status

FROM ma.v_isa_early_warning_engine
GROUP BY country_iso3, year;