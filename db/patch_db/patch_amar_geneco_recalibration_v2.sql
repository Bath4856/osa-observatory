-- ============================================================
-- OSA / ISA — Patch recalibration seuils AMAR + GENECO
-- Sprint 6 — Mai 2026
--
-- Contexte : après imputation complète MICE (L2) et
-- renormalisation L3 sur 135 indicateurs, la distribution
-- des scores AMAR/GENECO se comprime entre 0.29 et 0.71.
-- Les anciens seuils (0.25/0.45/0.65/0.80) sont inadaptés.
--
-- Nouveaux seuils ancrés sur les percentiles empiriques
-- 2010–2024 (médiane 0.562–0.610, écart-type 0.041–0.079) :
--
--   GREEN  < 0.350   (en dessous du min historique 0.291)
--   YELLOW  0.350–0.449
--   ORANGE  0.450–0.549   (autour P25)
--   RED     0.550–0.649   (autour médiane → P75)
--   BLACK  >= 0.650       (au-dessus P75 historique 0.638)
--
-- Distribution attendue 2024 après recalibration :
--   GREEN  : 0 pays   YELLOW : 1   ORANGE : 19   RED : 33   BLACK : 1
--
-- Vues modifiées :
--   ma.v_p7i_amar_atrocity_precursor_engine
--   ma.v_p7i_amar_geneco_dashboard
--   ma.v_p7i_amar_composite_dashboard
--   ma.v_p7i_amar_geneco_engine  (exposure_class)
--
-- Aucune donnée supprimée. Aucun score recalculé.
-- ============================================================

BEGIN;

-- DROP CASCADE pour permettre la recréation des vues avec colonnes modifiées
DROP VIEW IF EXISTS mg.v_public_p7i_amar_geneco_alerts CASCADE;
DROP VIEW IF EXISTS mg.v_public_p7i_amar_alerts CASCADE;
DROP VIEW IF EXISTS ma.v_p7i_amar_composite_dashboard CASCADE;
DROP VIEW IF EXISTS ma.v_p7i_amar_geneco_dashboard CASCADE;
DROP VIEW IF EXISTS ma.v_p7i_amar_geneco_engine CASCADE;
DROP VIEW IF EXISTS ma.v_p7i_amar_dashboard CASCADE;
DROP VIEW IF EXISTS ma.v_p7i_amar_atrocity_precursor_engine CASCADE;

-- ------------------------------------------------------------
-- 1. v_p7i_amar_atrocity_precursor_engine
--    Seuils sur atrocity_precursor_score
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW ma.v_p7i_amar_atrocity_precursor_engine AS
WITH base AS (
    SELECT
        country_iso3,
        year,
        pillar_code,
        COALESCE(threat_score,                 0)::numeric AS threat_score,
        COALESCE(strategic_risk_score,         0)::numeric AS strategic_risk_score,
        COALESCE(vulnerability_observed_score, 0)::numeric AS vulnerability_observed_score,
        COALESCE(weakness_score,               0)::numeric AS weakness_score,
        COALESCE(observation_confidence,       0)::numeric AS observation_confidence,
        COALESCE(forecast_observation_confidence,
                 observation_confidence,       0)::numeric AS forecast_confidence,
        COALESCE(ABS(stress_isa_delta),        0)::numeric AS abs_stress_delta,
        COALESCE(isa_volatility,               0)::numeric AS isa_volatility
    FROM ma.v_p7i_risk_source
),
domain_scores AS (
    SELECT
        country_iso3,
        year,

        -- Structural fragility : PHUM 35%, PECO 20%, PGEO 25%, PMON 20%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PHUM' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.35
                WHEN 'PECO' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.20
                WHEN 'PGEO' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.25
                WHEN 'PMON' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.20
                ELSE 0 END)
        ))::numeric AS structural_fragility_score,

        -- Conflict escalation : PMIL 45%, PGEO 35%, PTRA 20%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PMIL' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.45
                WHEN 'PGEO' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.35
                WHEN 'PTRA' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.20
                ELSE 0 END)
        ))::numeric AS conflict_escalation_score,

        -- Governance breakdown : PGEO 50%, PECO 20%, PNUM 15%, PMON 15%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PGEO' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.50
                WHEN 'PECO' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.20
                WHEN 'PNUM' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.15
                WHEN 'PMON' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.15
                ELSE 0 END)
        ))::numeric AS governance_breakdown_score,

        -- Humanitarian stress : PHUM 45%, PENV 30%, PECO 25%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PHUM' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.45
                WHEN 'PENV' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.30
                WHEN 'PECO' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.25
                ELSE 0 END)
        ))::numeric AS humanitarian_stress_score,

        -- Resource conflict : PMIN 50%, PRES 30%, PTRA 20%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PMIN' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.50
                WHEN 'PRES' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.30
                WHEN 'PTRA' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.20
                ELSE 0 END)
        ))::numeric AS resource_conflict_score,

        -- Information polarization : PNUM 60%, PGEO 40%
        LEAST(1.0, GREATEST(0.0,
            SUM(CASE pillar_code
                WHEN 'PNUM' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.60
                WHEN 'PGEO' THEN GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) * 0.40
                ELSE 0 END)
        ))::numeric AS information_polarization_score,

        -- Bonus volatilité et stress
        LEAST(0.10, AVG(abs_stress_delta))::numeric AS avg_stress_delta,
        LEAST(0.05, AVG(isa_volatility))::numeric   AS avg_isa_volatility,

        -- Confiance
        LEAST(1.0, GREATEST(0.0,
            AVG((observation_confidence * 0.60) + (forecast_confidence * 0.40))
        ))::numeric AS confidence_score,

        LEAST(1.0, GREATEST(0.0, AVG(abs_stress_delta)))::numeric AS avg_abs_isa_trend_slope,
        AVG(isa_volatility)::numeric                               AS avg_isa_volatility_raw,
        COUNT(DISTINCT pillar_code)::integer                       AS nb_pillars_monitored

    FROM base
    GROUP BY country_iso3, year
),
scored AS (
    SELECT
        country_iso3,
        year,
        structural_fragility_score,
        conflict_escalation_score,
        governance_breakdown_score,
        humanitarian_stress_score,
        resource_conflict_score,
        information_polarization_score,
        avg_stress_delta,
        avg_isa_volatility,
        confidence_score,
        avg_abs_isa_trend_slope,
        avg_isa_volatility_raw,
        nb_pillars_monitored,

        ROUND(LEAST(1.000, GREATEST(0.000,
            (structural_fragility_score    * 0.20) +
            (conflict_escalation_score     * 0.25) +
            (governance_breakdown_score    * 0.20) +
            (humanitarian_stress_score     * 0.15) +
            (resource_conflict_score       * 0.10) +
            (information_polarization_score* 0.10) +
            (avg_stress_delta              * 0.10) +
            (avg_isa_volatility            * 0.05)
        ))::numeric, 3) AS atrocity_precursor_score

    FROM domain_scores
)
SELECT
    country_iso3,
    year,
    ROUND(atrocity_precursor_score, 3)::numeric(6,3)  AS atrocity_precursor_score,
    ROUND(confidence_score, 3)::numeric(6,3)          AS confidence_score,
    nb_pillars_monitored,

    ROUND(structural_fragility_score,     3)::numeric(6,3) AS structural_fragility_score,
    ROUND(conflict_escalation_score,      3)::numeric(6,3) AS conflict_escalation_score,
    ROUND(governance_breakdown_score,     3)::numeric(6,3) AS governance_breakdown_score,
    ROUND(humanitarian_stress_score,      3)::numeric(6,3) AS humanitarian_stress_score,
    ROUND(resource_conflict_score,        3)::numeric(6,3) AS resource_conflict_score,
    ROUND(information_polarization_score, 3)::numeric(6,3) AS information_polarization_score,
    ROUND(avg_abs_isa_trend_slope,        3)::numeric(6,3) AS avg_abs_isa_trend_slope,
    ROUND(avg_isa_volatility_raw,         3)::numeric(6,3) AS avg_isa_volatility,
    ROUND(avg_stress_delta,               3)::numeric(6,3) AS avg_stress_delta,

    -- ── SEUILS RECALIBRÉS v2 (post L2/L3 complet) ──────────────────
    -- Ancrage : percentiles empiriques 2010–2024
    -- Médiane 0.562–0.610 | Écart-type 0.041–0.079
    -- GREEN < 0.350 | YELLOW 0.350–0.449 | ORANGE 0.450–0.549
    -- RED   0.550–0.649 | BLACK >= 0.650
    -- Sprint 6 — Mai 2026
    CASE
        WHEN confidence_score >= 0.700 THEN 'HIGH_CONFIDENCE'
        WHEN confidence_score >= 0.500 THEN 'MEDIUM_CONFIDENCE'
        WHEN confidence_score >= 0.350 THEN 'LOW_CONFIDENCE'
        ELSE 'VERY_LOW_CONFIDENCE'
    END AS confidence_class,

    CASE
        WHEN confidence_score      < 0.350 THEN 'LOW_CONFIDENCE'
        WHEN atrocity_precursor_score >= 0.650 THEN 'BLACK'
        WHEN atrocity_precursor_score >= 0.550 THEN 'RED'
        WHEN atrocity_precursor_score >= 0.450 THEN 'ORANGE'
        WHEN atrocity_precursor_score >= 0.350 THEN 'YELLOW'
        ELSE 'GREEN'
    END AS risk_band,

    CASE
        WHEN confidence_score      < 0.350 THEN 1
        WHEN atrocity_precursor_score >= 0.650 THEN 5
        WHEN atrocity_precursor_score >= 0.550 THEN 4
        WHEN atrocity_precursor_score >= 0.450 THEN 3
        WHEN atrocity_precursor_score >= 0.350 THEN 2
        ELSE 1
    END AS risk_rank,

    CASE
        WHEN confidence_score      < 0.350 THEN 'Contextual assessment — data confidence below threshold'
        WHEN atrocity_precursor_score >= 0.650 THEN 'Urgent civilian protection risk'
        WHEN atrocity_precursor_score >= 0.550 THEN 'Critical prevention risk'
        WHEN atrocity_precursor_score >= 0.450 THEN 'Early-warning atrocity precursor risk'
        WHEN atrocity_precursor_score >= 0.350 THEN 'Watchlist civilian protection risk'
        ELSE 'Low monitored civilian protection risk'
    END AS risk_interpretation

FROM scored;

-- ------------------------------------------------------------
-- 2. v_p7i_amar_geneco_engine
--    Seuils sur geneco_exposure_score (exposure_class)
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW ma.v_p7i_amar_geneco_engine AS
WITH base AS (
    SELECT
        country_iso3,
        year,
        pillar_code,
        COALESCE(threat_score,                 0)::numeric AS threat_score,
        COALESCE(strategic_risk_score,         0)::numeric AS strategic_risk_score,
        COALESCE(vulnerability_observed_score, 0)::numeric AS vulnerability_observed_score,
        COALESCE(observation_confidence,       0)::numeric AS observation_confidence,
        COALESCE(forecast_observation_confidence,
                 observation_confidence,       0)::numeric AS forecast_observation_confidence,
        COALESCE(ABS(stress_isa_delta),        0)::numeric AS abs_stress_delta,
        COALESCE(isa_volatility,               0)::numeric AS isa_volatility,
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
        country_iso3, year,
        LEAST(1.0, GREATEST(0.0, SUM(CASE pillar_code
            WHEN 'PMIN' THEN risk_component * 0.60
            WHEN 'PRES' THEN risk_component * 0.40
            ELSE 0 END)))::numeric AS resource_capture_risk,
        LEAST(1.0, GREATEST(0.0, SUM(CASE pillar_code
            WHEN 'PTRA' THEN risk_component * 0.65
            WHEN 'PMIL' THEN risk_component * 0.35
            ELSE 0 END)))::numeric AS logistics_enabling_risk,
        LEAST(1.0, GREATEST(0.0, SUM(CASE pillar_code
            WHEN 'PGEO' THEN risk_component * 0.50
            WHEN 'PECO' THEN risk_component * 0.25
            WHEN 'PMON' THEN risk_component * 0.25
            ELSE 0 END)))::numeric AS institutional_capture_risk,
        LEAST(1.0, GREATEST(0.0, SUM(CASE pillar_code
            WHEN 'PHUM' THEN risk_component * 1.00
            ELSE 0 END)))::numeric AS civilian_exploitation_risk,
        LEAST(1.0, GREATEST(0.0, SUM(CASE pillar_code
            WHEN 'PNUM' THEN risk_component * 0.60
            WHEN 'PGEO' THEN risk_component * 0.40
            ELSE 0 END)))::numeric AS narrative_weaponization_risk,
        LEAST(1.0, GREATEST(0.0, AVG(
            (COALESCE(observation_confidence, 0) * 0.60) +
            (COALESCE(forecast_observation_confidence, 0) * 0.40)
        )))::numeric AS geneco_confidence_score,
        COUNT(DISTINCT pillar_code)::integer AS nb_pillars_used
    FROM base
    GROUP BY country_iso3, year
),
scored AS (
    SELECT
        country_iso3, year,
        ROUND(resource_capture_risk,        3)::numeric(6,3) AS resource_capture_risk,
        ROUND(logistics_enabling_risk,      3)::numeric(6,3) AS logistics_enabling_risk,
        ROUND(institutional_capture_risk,   3)::numeric(6,3) AS institutional_capture_risk,
        ROUND(civilian_exploitation_risk,   3)::numeric(6,3) AS civilian_exploitation_risk,
        ROUND(narrative_weaponization_risk, 3)::numeric(6,3) AS narrative_weaponization_risk,
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
    country_iso3, year,
    resource_capture_risk,
    logistics_enabling_risk,
    institutional_capture_risk,
    civilian_exploitation_risk,
    narrative_weaponization_risk,
    geneco_exposure_score,
    geneco_confidence_score,
    nb_pillars_used,

    -- ── SEUILS RECALIBRÉS v2 ────────────────────────────────────────
    CASE
        WHEN geneco_confidence_score  < 0.350 THEN 'GENECO_CONTEXTUAL_LOW_CONFIDENCE'
        WHEN geneco_exposure_score   >= 0.650 THEN 'GENECO_EXTREME_EXPOSURE'
        WHEN geneco_exposure_score   >= 0.550 THEN 'GENECO_HIGH_EXPOSURE'
        WHEN geneco_exposure_score   >= 0.450 THEN 'GENECO_ELEVATED_EXPOSURE'
        WHEN geneco_exposure_score   >= 0.350 THEN 'GENECO_WATCHLIST'
        ELSE                                       'GENECO_LOW_MONITORING'
    END AS geneco_exposure_class,

    CASE
        WHEN geneco_confidence_score  < 0.350 THEN 'Expert review required due to low confidence.'
        WHEN geneco_exposure_score   >= 0.650 THEN 'Urgent conflict-economy exposure review required.'
        WHEN geneco_exposure_score   >= 0.550 THEN 'High conflict-economy exposure: prevention and due-diligence review recommended.'
        WHEN geneco_exposure_score   >= 0.450 THEN 'Elevated exposure: reinforced monitoring recommended.'
        WHEN geneco_exposure_score   >= 0.350 THEN 'Watchlist exposure: regular monitoring recommended.'
        ELSE                                       'Low monitored exposure.'
    END AS geneco_recommended_action,

    'P7I-AMAR-GENECO does not create a pillar and does not attribute legal responsibility.'::text
        AS methodology_note

FROM scored;

-- ------------------------------------------------------------
-- 3. v_p7i_amar_geneco_dashboard
--    Seuils sur geneco_exposure_score (risk_band)
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW ma.v_p7i_amar_geneco_dashboard AS
SELECT
    country_iso3,
    year,
    'CONFLICT_ECONOMY_EXPOSURE'::varchar(50) AS risk_code,
    geneco_exposure_score AS risk_score,
    geneco_confidence_score AS confidence_score,
    geneco_exposure_class AS risk_class,
    -- ── SEUILS RECALIBRÉS v2 ──────────────────────────────────────
    CASE
        WHEN geneco_confidence_score < 0.350 THEN 'LOW_CONFIDENCE'
        WHEN geneco_exposure_score  >= 0.650 THEN 'BLACK'
        WHEN geneco_exposure_score  >= 0.550 THEN 'RED'
        WHEN geneco_exposure_score  >= 0.450 THEN 'ORANGE'
        WHEN geneco_exposure_score  >= 0.350 THEN 'YELLOW'
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

-- ------------------------------------------------------------
-- 4b. v_p7i_amar_dashboard (supprimée par CASCADE — recréation)
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW ma.v_p7i_amar_dashboard AS
SELECT
    a.country_iso3,
    a.year,
    'ATROCITY_PRECURSOR'::varchar(50) AS risk_code,
    a.risk_band,
    a.risk_rank,
    a.atrocity_precursor_score AS risk_score,
    a.confidence_score,
    a.confidence_class,
    a.risk_interpretation,
    a.nb_pillars_monitored,
    a.structural_fragility_score,
    a.conflict_escalation_score,
    a.governance_breakdown_score,
    a.humanitarian_stress_score,
    a.resource_conflict_score,
    a.information_polarization_score,
    a.avg_abs_isa_trend_slope,
    a.avg_isa_volatility,
    a.avg_stress_delta,
    cy.country_early_warning_score,
    cy.country_early_warning_confidence,
    cy.country_sovereign_alert_level,
    cy.country_early_warning_status,
    CASE
        WHEN a.risk_band = 'BLACK' THEN 'URGENT_CIVILIAN_PROTECTION_REVIEW'
        WHEN a.risk_band = 'RED'   THEN 'PREVENTION_ACTION_REQUIRED'
        WHEN a.risk_band = 'ORANGE' THEN 'EARLY_WARNING_REVIEW_REQUIRED'
        WHEN a.risk_band = 'YELLOW' THEN 'MONITORING_REQUIRED'
        ELSE 'NORMAL_MONITORING'
    END AS recommended_action,
    CASE
        WHEN a.risk_band = 'BLACK'
            THEN 'Urgent civilian protection risk. Preventive review required. This is an early-warning signal, not a legal qualification.'
        WHEN a.risk_band = 'RED'
            THEN 'Critical prevention risk requiring institutional review. This is not a legal qualification.'
        WHEN a.risk_band = 'ORANGE'
            THEN 'Early-warning atrocity precursor risk requiring reinforced monitoring.'
        WHEN a.risk_band = 'YELLOW'
            THEN 'Watchlist civilian protection risk requiring regular monitoring.'
        ELSE 'Low monitored civilian protection risk.'
    END AS public_narrative,
    CASE WHEN a.confidence_score < 0.40 THEN TRUE ELSE FALSE END AS confidence_review_required
FROM ma.v_p7i_amar_atrocity_precursor_engine a
LEFT JOIN ma.v_isa_early_warning_country_year cy
       ON cy.country_iso3 = a.country_iso3 AND cy.year = a.year;

-- ------------------------------------------------------------
-- 4. v_p7i_amar_composite_dashboard
--    Seuils sur amar_composite_score
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW ma.v_p7i_amar_composite_dashboard AS
WITH amar AS (
    SELECT
        country_iso3, year,
        risk_score::numeric           AS atrocity_precursor_score,
        confidence_score::numeric     AS atrocity_confidence_score,
        risk_band                     AS atrocity_risk_band
    FROM ma.v_p7i_amar_dashboard
),
geneco AS (
    SELECT
        country_iso3, year,
        risk_score::numeric           AS geneco_exposure_score,
        confidence_score::numeric     AS geneco_confidence_score,
        risk_band                     AS geneco_risk_band,
        resource_capture_risk,
        logistics_enabling_risk,
        institutional_capture_risk,
        civilian_exploitation_risk,
        narrative_weaponization_risk
    FROM ma.v_p7i_amar_geneco_dashboard
),
scored AS (
    SELECT
        COALESCE(a.country_iso3, g.country_iso3) AS country_iso3,
        COALESCE(a.year,         g.year)          AS year,
        COALESCE(a.atrocity_precursor_score, 0)::numeric AS atrocity_precursor_score,
        COALESCE(g.geneco_exposure_score,    0)::numeric AS geneco_exposure_score,
        LEAST(1.0, GREATEST(0.0,
            (COALESCE(a.atrocity_precursor_score, 0) * 0.70) +
            (COALESCE(g.geneco_exposure_score,    0) * 0.30)
        ))::numeric AS amar_composite_score,
        LEAST(1.0, GREATEST(0.0,
            (COALESCE(a.atrocity_confidence_score, 0) * 0.60) +
            (COALESCE(g.geneco_confidence_score,   0) * 0.40)
        ))::numeric AS amar_composite_confidence,
        a.atrocity_risk_band,
        g.geneco_risk_band,
        g.resource_capture_risk,
        g.logistics_enabling_risk,
        g.institutional_capture_risk,
        g.civilian_exploitation_risk,
        g.narrative_weaponization_risk
    FROM amar a
    FULL OUTER JOIN geneco g
      ON g.country_iso3 = a.country_iso3 AND g.year = a.year
)
SELECT
    country_iso3, year,
    ROUND(atrocity_precursor_score,  3)::numeric(6,3) AS atrocity_precursor_score,
    ROUND(geneco_exposure_score,     3)::numeric(6,3) AS geneco_exposure_score,
    ROUND(amar_composite_score,      3)::numeric(6,3) AS amar_composite_score,
    ROUND(amar_composite_confidence, 3)::numeric(6,3) AS amar_composite_confidence,
    atrocity_risk_band,
    geneco_risk_band,

    -- ── SEUILS RECALIBRÉS v2 ──────────────────────────────────────
    CASE
        WHEN amar_composite_confidence < 0.350 THEN 'LOW_CONFIDENCE'
        WHEN amar_composite_score      >= 0.650 THEN 'BLACK'
        WHEN amar_composite_score      >= 0.550 THEN 'RED'
        WHEN amar_composite_score      >= 0.450 THEN 'ORANGE'
        WHEN amar_composite_score      >= 0.350 THEN 'YELLOW'
        ELSE 'GREEN'
    END AS amar_composite_band,

    resource_capture_risk,
    logistics_enabling_risk,
    institutional_capture_risk,
    civilian_exploitation_risk,
    narrative_weaponization_risk,

    CASE
        WHEN amar_composite_confidence < 0.350 THEN 'Composite AMAR result is contextual: expert review required.'
        WHEN amar_composite_score      >= 0.650 THEN 'Urgent civilian protection and conflict-economy review required.'
        WHEN amar_composite_score      >= 0.550 THEN 'Critical prevention review recommended.'
        WHEN amar_composite_score      >= 0.450 THEN 'Reinforced early-warning monitoring recommended.'
        WHEN amar_composite_score      >= 0.350 THEN 'Watchlist monitoring recommended.'
        ELSE 'Normal monitoring.'
    END AS composite_recommended_action

FROM scored;


-- ------------------------------------------------------------
-- 5. Recréation des vues publiques mg.* (supprimées par CASCADE)
-- ------------------------------------------------------------

CREATE VIEW mg.v_public_p7i_amar_alerts AS
SELECT
    country_iso3,
    year,
    risk_code,
    risk_band,
    ROUND(risk_score, 3)::numeric(6,3)       AS risk_score,
    ROUND(confidence_score, 3)::numeric(6,3) AS confidence_score,
    source_engine,
    public_narrative,
    created_at,
    updated_at
FROM mg.early_warning_alerts
WHERE source_engine = 'P7I-AMAR'
  AND risk_code = 'ATROCITY_PRECURSOR';

CREATE VIEW mg.v_public_p7i_amar_geneco_alerts AS
SELECT
    country_iso3,
    year,
    risk_code,
    risk_band,
    ROUND(risk_score, 3)::numeric(6,3)       AS risk_score,
    ROUND(confidence_score, 3)::numeric(6,3) AS confidence_score,
    risk_class,
    recommended_action,
    'Conflict-economy exposure signal. This is not legal attribution and not a genocide determination.'::text AS public_disclaimer
FROM ma.v_p7i_amar_geneco_dashboard;

-- ------------------------------------------------------------
-- 6. Vérification post-patch
-- ------------------------------------------------------------

SELECT
    'AMAR 2024' AS source,
    risk_band,
    COUNT(*) AS nb_pays,
    ROUND(AVG(risk_score)::numeric, 3) AS avg_score
FROM ma.v_p7i_amar_dashboard
WHERE year = 2024
GROUP BY risk_band

UNION ALL

SELECT
    'GENECO 2024',
    risk_band,
    COUNT(*),
    ROUND(AVG(risk_score)::numeric, 3)
FROM ma.v_p7i_amar_geneco_dashboard
WHERE year = 2024
GROUP BY risk_band

ORDER BY source, risk_band;

COMMIT;
