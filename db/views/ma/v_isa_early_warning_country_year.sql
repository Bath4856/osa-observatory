-- ============================================================
-- PATCH : recalibrage alertes pays
-- fichier : db/patch_isa_country_warning_recalibration.sql
-- OSA / ISA Observatory
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_early_warning_country_year AS
WITH base AS (
    SELECT
        country_iso3,
        year,

        COUNT(*) AS nb_pillars_monitored,

        ROUND(AVG(early_warning_score), 3) AS country_early_warning_score,
        ROUND(AVG(early_warning_confidence), 3) AS country_early_warning_confidence,

        SUM(CASE WHEN sovereign_alert_level = 'RED' THEN 1 ELSE 0 END) AS nb_red_alerts,
        SUM(CASE WHEN sovereign_alert_level = 'ORANGE' THEN 1 ELSE 0 END) AS nb_orange_alerts,
        SUM(CASE WHEN sovereign_alert_level = 'YELLOW' THEN 1 ELSE 0 END) AS nb_yellow_alerts,
        SUM(CASE WHEN sovereign_alert_level = 'GREEN' THEN 1 ELSE 0 END) AS nb_green_alerts,

        ROUND(AVG(fragility_warning_score), 3) AS avg_fragility_warning_score,
        ROUND(AVG(stress_propagation_score), 3) AS avg_stress_propagation_score

    FROM ma.v_isa_early_warning_engine
    GROUP BY country_iso3, year
)

SELECT
    *,
    CASE
        WHEN nb_red_alerts >= 1
            THEN 'RED'

        WHEN nb_orange_alerts >= 6
          OR country_early_warning_score >= 0.500
            THEN 'ORANGE'

        WHEN nb_orange_alerts >= 1
          OR country_early_warning_score >= 0.350
            THEN 'YELLOW'

        ELSE 'GREEN'
    END AS country_sovereign_alert_level,

    CASE
        WHEN nb_red_alerts >= 1
            THEN 'COUNTRY_CRITICAL_ALERT'

        WHEN nb_orange_alerts >= 6
          OR country_early_warning_score >= 0.500
            THEN 'COUNTRY_WARNING_STRATEGIC_REVIEW_REQUIRED'

        WHEN nb_orange_alerts >= 1
          OR country_early_warning_score >= 0.350
            THEN 'COUNTRY_WARNING_MONITOR'

        ELSE 'COUNTRY_STABLE'
    END AS country_early_warning_status

FROM base;