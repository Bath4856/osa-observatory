-- ============================================================
-- OSA / ISA — P7I-AMAR-GENECO Engine
-- Conflict Economy Exposure Engine
-- CORRECTIF v3 : source corrigée vers ma.v_p7i_risk_source
--   (cohérent avec v_p7i_amar_atrocity_precursor_engine)
-- Colonnes utilisées : toutes confirmées dans AUDIT_P7I_AMAR_REAL.md
-- Score scale: 0.000 to 1.000
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7i_amar_geneco_engine AS
WITH base AS (
    SELECT
        country_iso3,
        year,
        pillar_code,

        COALESCE(threat_score, 0)::numeric              AS threat_score,
        COALESCE(strategic_risk_score, 0)::numeric      AS strategic_risk_score,
        COALESCE(vulnerability_observed_score, 0)::numeric AS vulnerability_observed_score,
        COALESCE(weakness_score, 0)::numeric            AS weakness_score,
        COALESCE(observation_confidence, 0)::numeric    AS observation_confidence,
        COALESCE(forecast_observation_confidence,
                 observation_confidence, 0)::numeric    AS forecast_observation_confidence,
        COALESCE(stress_isa_delta, 0)::numeric          AS stress_isa_delta,
        COALESCE(isa_volatility, 0)::numeric            AS isa_volatility,

        -- composante de risque unifiée (cohérente avec AMAR precursor)
        LEAST(1.000, GREATEST(0.000,
            COALESCE(threat_score, 0),
            COALESCE(strategic_risk_score, 0),
            COALESCE(vulnerability_observed_score, 0),
            ABS(COALESCE(stress_isa_delta, 0))
        ))::numeric AS risk_component

    FROM ma.v_p7i_risk_source
),
components AS (
    SELECT
        country_iso3,
        year,

        -- A. Resource capture : PMIN 60%, PRES 40%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PMIN' THEN risk_component * 0.60
                WHEN 'PRES' THEN risk_component * 0.40
                ELSE 0 END)
        ))::numeric AS resource_capture_risk,

        -- B. Logistics enabling : PTRA 65%, PMIL 35%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PTRA' THEN risk_component * 0.65
                WHEN 'PMIL' THEN risk_component * 0.35
                ELSE 0 END)
        ))::numeric AS logistics_enabling_risk,

        -- C. Institutional capture : PGEO 50%, PECO 25%, PMON 25%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PGEO' THEN risk_component * 0.50
                WHEN 'PECO' THEN risk_component * 0.25
                WHEN 'PMON' THEN risk_component * 0.25
                ELSE 0 END)
        ))::numeric AS institutional_capture_risk,

        -- D. Civilian exploitation : PHUM 100%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PHUM' THEN risk_component * 1.00
                ELSE 0 END)
        ))::numeric AS civilian_exploitation_risk,

        -- E. Narrative weaponization : PNUM 60%, PGEO 40%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PNUM' THEN risk_component * 0.60
                WHEN 'PGEO' THEN risk_component * 0.40
                ELSE 0 END)
        ))::numeric AS narrative_weaponization_risk,

        -- Confidence : observation + forecast
        LEAST(1.0, GREATEST(0.0,
            AVG(
                (COALESCE(observation_confidence, 0) * 0.60) +
                (COALESCE(forecast_observation_confidence, 0) * 0.40)
            )
        ))::numeric AS geneco_confidence_score,

        COUNT(DISTINCT pillar_code)::integer AS nb_pillars_used

    FROM base
    GROUP BY country_iso3, year
),
scored AS (
    SELECT
        country_iso3,
        year,
        ROUND(resource_capture_risk,       3)::numeric(6,3) AS resource_capture_risk,
        ROUND(logistics_enabling_risk,     3)::numeric(6,3) AS logistics_enabling_risk,
        ROUND(institutional_capture_risk,  3)::numeric(6,3) AS institutional_capture_risk,
        ROUND(civilian_exploitation_risk,  3)::numeric(6,3) AS civilian_exploitation_risk,
        ROUND(narrative_weaponization_risk,3)::numeric(6,3) AS narrative_weaponization_risk,

        -- Score composite GENECO : pondérations du spec
        ROUND(LEAST(1.0, GREATEST(0.0,
            (resource_capture_risk       * 0.30) +
            (logistics_enabling_risk     * 0.20) +
            (institutional_capture_risk  * 0.25) +
            (civilian_exploitation_risk  * 0.15) +
            (narrative_weaponization_risk* 0.10)
        )), 3)::numeric(6,3) AS geneco_exposure_score,

        ROUND(geneco_confidence_score, 3)::numeric(6,3) AS geneco_confidence_score,
        nb_pillars_used
    FROM components
)
SELECT
    country_iso3,
    year,
    resource_capture_risk,
    logistics_enabling_risk,
    institutional_capture_risk,
    civilian_exploitation_risk,
    narrative_weaponization_risk,
    geneco_exposure_score,
    geneco_confidence_score,
    nb_pillars_used,

    CASE
        WHEN geneco_confidence_score  < 0.350 THEN 'GENECO_CONTEXTUAL_LOW_CONFIDENCE'
        WHEN geneco_exposure_score   >= 0.800 THEN 'GENECO_EXTREME_EXPOSURE'
        WHEN geneco_exposure_score   >= 0.650 THEN 'GENECO_HIGH_EXPOSURE'
        WHEN geneco_exposure_score   >= 0.450 THEN 'GENECO_ELEVATED_EXPOSURE'
        WHEN geneco_exposure_score   >= 0.250 THEN 'GENECO_WATCHLIST'
        ELSE                                       'GENECO_LOW_MONITORING'
    END AS geneco_exposure_class,

    CASE
        WHEN geneco_confidence_score  < 0.350 THEN 'Expert review required due to low confidence.'
        WHEN geneco_exposure_score   >= 0.800 THEN 'Urgent conflict-economy exposure review required.'
        WHEN geneco_exposure_score   >= 0.650 THEN 'High conflict-economy exposure: prevention and due-diligence review recommended.'
        WHEN geneco_exposure_score   >= 0.450 THEN 'Elevated exposure: reinforced monitoring recommended.'
        WHEN geneco_exposure_score   >= 0.250 THEN 'Watchlist exposure: regular monitoring recommended.'
        ELSE                                       'Low monitored exposure.'
    END AS geneco_recommended_action,

    'P7I-AMAR-GENECO does not create a pillar and does not attribute legal responsibility.'::text
        AS methodology_note

FROM scored;
