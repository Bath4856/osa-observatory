CREATE MATERIALIZED VIEW ma.mv_p7i_amar_composite_dashboard AS
WITH amar AS (
    SELECT country_iso3, year,
           risk_score::numeric AS atrocity_precursor_score,
           confidence_score::numeric AS atrocity_confidence_score,
           risk_band AS atrocity_risk_band
    FROM ma.v_p7i_amar_dashboard
), geneco AS (
    SELECT country_iso3, year,
           risk_score::numeric AS geneco_exposure_score,
           confidence_score::numeric AS geneco_confidence_score,
           risk_band AS geneco_risk_band,
           resource_capture_risk, logistics_enabling_risk,
           institutional_capture_risk, civilian_exploitation_risk,
           narrative_weaponization_risk
    FROM ma.v_p7i_amar_geneco_dashboard
), scored AS (
    SELECT
        COALESCE(a.country_iso3, g.country_iso3) AS country_iso3,
        COALESCE(a.year, g.year) AS year,
        COALESCE(a.atrocity_precursor_score, 0::numeric) AS atrocity_precursor_score,
        COALESCE(g.geneco_exposure_score, 0::numeric) AS geneco_exposure_score,
        LEAST(1.0, GREATEST(0.0, COALESCE(a.atrocity_precursor_score, 0::numeric) * 0.70 + COALESCE(g.geneco_exposure_score, 0::numeric) * 0.30)) AS amar_composite_score,
        LEAST(1.0, GREATEST(0.0, COALESCE(a.atrocity_confidence_score, 0::numeric) * 0.60 + COALESCE(g.geneco_confidence_score, 0::numeric) * 0.40)) AS amar_composite_confidence,
        a.atrocity_risk_band, g.geneco_risk_band,
        g.resource_capture_risk, g.logistics_enabling_risk,
        g.institutional_capture_risk, g.civilian_exploitation_risk,
        g.narrative_weaponization_risk
    FROM amar a
    FULL JOIN geneco g ON g.country_iso3 = a.country_iso3 AND g.year = a.year
)
SELECT country_iso3, year,
    round(atrocity_precursor_score, 3)::numeric(6,3) AS atrocity_precursor_score,
    round(geneco_exposure_score, 3)::numeric(6,3) AS geneco_exposure_score,
    round(amar_composite_score, 3)::numeric(6,3) AS amar_composite_score,
    round(amar_composite_confidence, 3)::numeric(6,3) AS amar_composite_confidence,
    atrocity_risk_band, geneco_risk_band,
    CASE
        WHEN amar_composite_confidence < 0.350 THEN 'LOW_CONFIDENCE'
        WHEN amar_composite_score >= 0.800 THEN 'BLACK'
        WHEN amar_composite_score >= 0.650 THEN 'RED'
        WHEN amar_composite_score >= 0.450 THEN 'ORANGE'
        WHEN amar_composite_score >= 0.250 THEN 'YELLOW'
        ELSE 'GREEN'
    END AS amar_composite_band,
    resource_capture_risk, logistics_enabling_risk,
    institutional_capture_risk, civilian_exploitation_risk,
    narrative_weaponization_risk,
    CASE
        WHEN amar_composite_confidence < 0.350 THEN 'Composite AMAR result is contextual: expert review required.'
        WHEN amar_composite_score >= 0.800 THEN 'Urgent civilian protection and conflict-economy review required.'
        WHEN amar_composite_score >= 0.650 THEN 'Critical prevention review recommended.'
        WHEN amar_composite_score >= 0.450 THEN 'Reinforced early-warning monitoring recommended.'
        WHEN amar_composite_score >= 0.250 THEN 'Watchlist monitoring recommended.'
        ELSE 'Normal monitoring.'
    END AS composite_recommended_action
FROM scored;

CREATE UNIQUE INDEX idx_mv_amar_composite_country_year
    ON ma.mv_p7i_amar_composite_dashboard (country_iso3, year);

COMMENT ON MATERIALIZED VIEW ma.mv_p7i_amar_composite_dashboard IS
    'Vue materialisee -- composite AMAR + GENECO. Sprint 19 -- resolution timeout 504.';
