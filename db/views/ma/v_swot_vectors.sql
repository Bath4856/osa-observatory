-- ============================================================
-- OSA / ISA — P6
-- Vue : ma.v_swot_vectors
-- Rôle : CONSOMMER les signaux SWOT déjà calculés en L3
-- Source : ma.computed_values
-- Ne recalcule PAS le SWOT.
-- Convention P6 : year legacy -> obs_year en sortie
-- ============================================================

-- CREATE OR REPLACE VIEW ma.v_swot_vectors AS
DROP VIEW IF EXISTS ma.v_swot_vectors CASCADE;

CREATE VIEW ma.v_swot_vectors AS

WITH l3_swot AS (
    SELECT
        cv.country_iso3,
        cv.year::SMALLINT AS obs_year,

        cv.indicator_code AS swot_code,

        -- Codes attendus : WKN_PMIN, THR_PGEO, etc.
     --   SPLIT_PART(cv.indicator_code, '_', 2) AS pillar_code,
        CAST( SPLIT_PART(cv.indicator_code, '_', 2)
                AS VARCHAR(10)
            ) AS pillar_code,

        COALESCE(cv.value, 0)::NUMERIC AS swot_value,
        COALESCE(cv.confidence, 0.80)::NUMERIC AS swot_confidence,

        COALESCE(cv.nb_indicators, 0) AS nb_indicators

    FROM ma.computed_values cv
    WHERE cv.indicator_code LIKE 'WKN_%'
       OR cv.indicator_code LIKE 'THR_%'
       OR cv.indicator_code LIKE 'FRC_%'
       OR cv.indicator_code LIKE 'FOR_%'
       OR cv.indicator_code LIKE 'OPP_%'
),

typed AS (
    SELECT
        country_iso3,
        obs_year,
        pillar_code,

        CASE
            WHEN swot_code LIKE 'FRC_%'
              OR swot_code LIKE 'FOR_%'
                THEN 'FORCE'

            WHEN swot_code LIKE 'OPP_%'
                THEN 'OPPORTUNITE'

            WHEN swot_code LIKE 'WKN_%'
                THEN 'FAIBLESSE'

            WHEN swot_code LIKE 'THR_%'
                THEN 'MENACE'

            ELSE 'UNKNOWN'
        END AS swot_type,

        swot_value,
        swot_confidence,
        nb_indicators

    FROM l3_swot
)

SELECT
    country_iso3,
    obs_year,
    pillar_code,

    ROUND(
        AVG(swot_value) FILTER (WHERE swot_type = 'FORCE'),
        3
    ) AS force_score,

    ROUND(
        AVG(swot_value) FILTER (WHERE swot_type = 'OPPORTUNITE'),
        3
    ) AS opportunity_score,

    ROUND(
        AVG(swot_value) FILTER (WHERE swot_type = 'FAIBLESSE'),
        3
    ) AS weakness_score,

    ROUND(
        AVG(swot_value) FILTER (WHERE swot_type = 'MENACE'),
        3
    ) AS threat_score,

    ROUND(AVG(swot_confidence), 3) AS swot_confidence,

    COUNT(*) FILTER (WHERE swot_type = 'FORCE')       AS force_count,
    COUNT(*) FILTER (WHERE swot_type = 'OPPORTUNITE') AS opportunity_count,
    COUNT(*) FILTER (WHERE swot_type = 'FAIBLESSE')   AS weakness_count,
    COUNT(*) FILTER (WHERE swot_type = 'MENACE')      AS threat_count,

    COUNT(*) AS total_swot_signals,

    SUM(nb_indicators) AS total_swot_components,

    ROUND(
        (
            COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'FORCE'), 0)
          + COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'OPPORTUNITE'), 0)
          - COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'FAIBLESSE'), 0)
          - COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'MENACE'), 0)
        )::NUMERIC,
        3
    ) AS swot_balance_score,

    CASE
        WHEN COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'FAIBLESSE'), 0) >= 0.70
         AND COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'MENACE'), 0) >= 0.70
            THEN 'CRITICAL_VULNERABILITY'

        WHEN COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'FAIBLESSE'), 0) >= 0.60
          OR COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'MENACE'), 0) >= 0.60
            THEN 'HIGH_VULNERABILITY'

        WHEN COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'FORCE'), 0) >= 0.70
         AND COALESCE(AVG(swot_value) FILTER (WHERE swot_type = 'OPPORTUNITE'), 0) >= 0.60
            THEN 'STRATEGIC_LEVERAGE'

        ELSE 'BALANCED'
    END AS swot_signal_class

FROM typed
GROUP BY
    country_iso3,
    obs_year,
    pillar_code;