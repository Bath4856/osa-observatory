-- ============================================================
-- OSA / ISA — P7I-AMAR-GENECO Dashboard
-- Dashboard layer for API / audit / P8 publication mapping.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7i_amar_geneco_dashboard AS
SELECT
    country_iso3,
    year,
    'CONFLICT_ECONOMY_EXPOSURE'::varchar(50) AS risk_code,
    geneco_exposure_score AS risk_score,
    geneco_confidence_score AS confidence_score,
    geneco_exposure_class AS risk_class,
    CASE
        WHEN geneco_confidence_score < 0.350 THEN 'LOW_CONFIDENCE'
        WHEN geneco_exposure_score >= 0.800 THEN 'BLACK'
        WHEN geneco_exposure_score >= 0.650 THEN 'RED'
        WHEN geneco_exposure_score >= 0.450 THEN 'ORANGE'
        WHEN geneco_exposure_score >= 0.250 THEN 'YELLOW'
        ELSE 'GREEN'
    END AS risk_band,
    resource_capture_risk,
    logistics_enabling_risk,
    institutional_capture_risk,
    civilian_exploitation_risk,
    narrative_weaponization_risk,
    nb_pillars_used,
    geneco_recommended_action AS recommended_action,
    methodology_note
FROM ma.v_p7i_amar_geneco_engine;
