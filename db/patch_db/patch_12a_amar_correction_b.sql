-- ============================================================
-- OSA Observatory -- Sprint 12A
-- Recalibration AMAR -- Correction B
-- v_p7i_amar_atrocity_precursor_engine
-- 
-- Probleme identifie :
--   strategic_risk_score = 0 en 2010-2019 (aucun signal SWOT)
--   strategic_risk_score = 0.76 en 2020+ (SWOT actif)
--   => Rupture artificielle GREEN->YELLOW en 2020
--
-- Correction B :
--   Si swot_data_status = 'NO_COMPUTED_SWOT_ATTACHED'
--   => utiliser vulnerability_observed_score uniquement
--   Sinon => GREATEST(threat, strategic_risk, vulnerability)
--
-- Doctrine ISA v1 Axiome 3 :
--   La qualite se qualifie, ne s'exclut pas.
--   Face a une donnee absente (SWOT non calcule),
--   on qualifie l'absence et on utilise ce qui est disponible.
-- ============================================================

BEGIN;

DROP VIEW IF EXISTS ma.v_p7i_amar_dashboard CASCADE;
DROP VIEW IF EXISTS ma.v_p7i_amar_atrocity_precursor_engine CASCADE;

CREATE VIEW ma.v_p7i_amar_atrocity_precursor_engine AS

WITH base AS (
    SELECT
        country_iso3,
        year,
        pillar_code,
        swot_data_status,
        COALESCE(threat_score,              0) AS threat_score,
        COALESCE(strategic_risk_score,      0) AS strategic_risk_score,
        COALESCE(vulnerability_observed_score, 0) AS vulnerability_observed_score,
        COALESCE(observation_confidence,    0) AS observation_confidence,
        COALESCE(forecast_observation_confidence,
                 observation_confidence,    0) AS forecast_confidence,
        COALESCE(ABS(isa_trend_slope),      0) AS abs_stress_delta,
        COALESCE(isa_volatility,            0) AS isa_volatility
    FROM ma.v_p7i_risk_source
),

-- Correction B : score effectif selon disponibilite SWOT
base_corrected AS (
    SELECT
        *,
        -- Si SWOT absent : on ne peut pas evaluer les faiblesses
        -- On utilise uniquement vulnerability_observed_score
        -- Sinon : GREATEST des trois dimensions disponibles
        CASE
            WHEN swot_data_status = 'NO_COMPUTED_SWOT_ATTACHED'
            THEN vulnerability_observed_score
            ELSE GREATEST(
                threat_score,
                strategic_risk_score,
                vulnerability_observed_score
            )
        END AS effective_risk_score
    FROM base
),

domain_scores AS (
    SELECT
        country_iso3,
        year,

        -- Fragilite structurelle (PHUM 35%, PECO 20%, PGEO 25%, PMON 20%)
        LEAST(1.0, GREATEST(0.0, SUM(
            CASE pillar_code
                WHEN 'PHUM' THEN effective_risk_score * 0.35
                WHEN 'PECO' THEN effective_risk_score * 0.20
                WHEN 'PGEO' THEN effective_risk_score * 0.25
                WHEN 'PMON' THEN effective_risk_score * 0.20
                ELSE 0
            END
        ))) AS structural_fragility_score,

        -- Escalade conflictuelle (PMIL 45%, PGEO 35%, PTRA 20%)
        LEAST(1.0, GREATEST(0.0, SUM(
            CASE pillar_code
                WHEN 'PMIL' THEN effective_risk_score * 0.45
                WHEN 'PGEO' THEN effective_risk_score * 0.35
                WHEN 'PTRA' THEN effective_risk_score * 0.20
                ELSE 0
            END
        ))) AS conflict_escalation_score,

        -- Effondrement gouvernance (PGEO 50%, PECO 20%, PNUM 15%, PMON 15%)
        LEAST(1.0, GREATEST(0.0, SUM(
            CASE pillar_code
                WHEN 'PGEO' THEN effective_risk_score * 0.50
                WHEN 'PECO' THEN effective_risk_score * 0.20
                WHEN 'PNUM' THEN effective_risk_score * 0.15
                WHEN 'PMON' THEN effective_risk_score * 0.15
                ELSE 0
            END
        ))) AS governance_breakdown_score,

        -- Stress humanitaire (PHUM 45%, PENV 30%, PECO 25%)
        LEAST(1.0, GREATEST(0.0, SUM(
            CASE pillar_code
                WHEN 'PHUM' THEN effective_risk_score * 0.45
                WHEN 'PENV' THEN effective_risk_score * 0.30
                WHEN 'PECO' THEN effective_risk_score * 0.25
                ELSE 0
            END
        ))) AS humanitarian_stress_score,

        -- Conflit ressources (PMIN 50%, PRES 30%, PTRA 20%)
        LEAST(1.0, GREATEST(0.0, SUM(
            CASE pillar_code
                WHEN 'PMIN' THEN effective_risk_score * 0.50
                WHEN 'PRES' THEN effective_risk_score * 0.30
                WHEN 'PTRA' THEN effective_risk_score * 0.20
                ELSE 0
            END
        ))) AS resource_conflict_score,

        -- Polarisation information (PNUM 60%, PGEO 40%)
        LEAST(1.0, GREATEST(0.0, SUM(
            CASE pillar_code
                WHEN 'PNUM' THEN effective_risk_score * 0.60
                WHEN 'PGEO' THEN effective_risk_score * 0.40
                ELSE 0
            END
        ))) AS information_polarization_score,

        -- Metriques temporelles
        LEAST(0.10, AVG(abs_stress_delta))  AS avg_stress_delta,
        LEAST(0.05, AVG(isa_volatility))    AS avg_isa_volatility,
        LEAST(1.0, GREATEST(0.0,
            AVG(observation_confidence * 0.60 + forecast_confidence * 0.40)
        ))                                  AS confidence_score,
        LEAST(1.0, GREATEST(0.0,
            AVG(abs_stress_delta)
        ))                                  AS avg_abs_isa_trend_slope,
        AVG(isa_volatility)                 AS avg_isa_volatility_raw,
        COUNT(DISTINCT pillar_code)::integer AS nb_pillars_monitored

    FROM base_corrected
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

        -- Score composite AMAR
        ROUND(LEAST(1.000, GREATEST(0.000,
            structural_fragility_score    * 0.20 +
            conflict_escalation_score     * 0.25 +
            governance_breakdown_score    * 0.20 +
            humanitarian_stress_score     * 0.15 +
            resource_conflict_score       * 0.10 +
            information_polarization_score * 0.10 +
            avg_stress_delta              * 0.10 +
            avg_isa_volatility            * 0.05
        )), 3) AS atrocity_precursor_score

    FROM domain_scores
)

SELECT
    country_iso3,
    year,
    ROUND(atrocity_precursor_score, 3)::NUMERIC(6,3) AS atrocity_precursor_score,
    ROUND(confidence_score, 3)::NUMERIC(6,3)         AS confidence_score,
    nb_pillars_monitored,
    ROUND(structural_fragility_score, 3)::NUMERIC(6,3)     AS structural_fragility_score,
    ROUND(conflict_escalation_score, 3)::NUMERIC(6,3)      AS conflict_escalation_score,
    ROUND(governance_breakdown_score, 3)::NUMERIC(6,3)     AS governance_breakdown_score,
    ROUND(humanitarian_stress_score, 3)::NUMERIC(6,3)      AS humanitarian_stress_score,
    ROUND(resource_conflict_score, 3)::NUMERIC(6,3)        AS resource_conflict_score,
    ROUND(information_polarization_score, 3)::NUMERIC(6,3) AS information_polarization_score,
    ROUND(avg_abs_isa_trend_slope, 3)::NUMERIC(6,3)        AS avg_abs_isa_trend_slope,
    ROUND(avg_isa_volatility_raw, 3)::NUMERIC(6,3)         AS avg_isa_volatility,
    ROUND(avg_stress_delta, 3)::NUMERIC(6,3)               AS avg_stress_delta,

    -- Classe de confiance
    CASE
        WHEN confidence_score >= 0.700 THEN 'HIGH_CONFIDENCE'
        WHEN confidence_score >= 0.500 THEN 'MEDIUM_CONFIDENCE'
        WHEN confidence_score >= 0.350 THEN 'LOW_CONFIDENCE'
        ELSE 'VERY_LOW_CONFIDENCE'
    END AS confidence_class,

    -- Bande de risque AMAR
    CASE
        WHEN confidence_score < 0.350          THEN 'LOW_CONFIDENCE'
        WHEN atrocity_precursor_score >= 0.650 THEN 'BLACK'
        WHEN atrocity_precursor_score >= 0.550 THEN 'RED'
        WHEN atrocity_precursor_score >= 0.450 THEN 'ORANGE'
        WHEN atrocity_precursor_score >= 0.350 THEN 'YELLOW'
        ELSE 'GREEN'
    END AS risk_band,

    -- Rang de risque
    CASE
        WHEN confidence_score < 0.350          THEN 1
        WHEN atrocity_precursor_score >= 0.650 THEN 5
        WHEN atrocity_precursor_score >= 0.550 THEN 4
        WHEN atrocity_precursor_score >= 0.450 THEN 3
        WHEN atrocity_precursor_score >= 0.350 THEN 2
        ELSE 1
    END AS risk_rank,

    -- Interpretation
    CASE
        WHEN confidence_score < 0.350
            THEN 'Contextual assessment — data confidence below threshold'
        WHEN atrocity_precursor_score >= 0.650
            THEN 'Urgent civilian protection risk'
        WHEN atrocity_precursor_score >= 0.550
            THEN 'Critical prevention risk'
        WHEN atrocity_precursor_score >= 0.450
            THEN 'Early-warning atrocity precursor risk'
        WHEN atrocity_precursor_score >= 0.350
            THEN 'Watchlist civilian protection risk'
        ELSE 'Low monitored civilian protection risk'
    END AS risk_interpretation

FROM scored;

-- ── Commentaire de gouvernance ────────────────────────────────
COMMENT ON VIEW ma.v_p7i_amar_atrocity_precursor_engine IS
'Sprint 12A -- Correction B -- Mai 2026
Correction de la rupture AMAR artificielle 2019->2020.
Cause : strategic_risk_score base sur weakness_score SWOT,
absent avant 2020 (swot_data_status = NO_COMPUTED_SWOT_ATTACHED).
Correction : effective_risk_score conditionnel sur swot_data_status.
Sans SWOT : vulnerability_observed_score uniquement.
Avec SWOT : GREATEST(threat, strategic_risk, vulnerability).
Doctrine ISA v1 Axiome 3 : la qualite se qualifie, ne s''exclut pas.';

-- ── Recreer v_p7i_amar_dashboard (dependante) ─────────────────
CREATE VIEW ma.v_p7i_amar_dashboard AS
SELECT
    a.country_iso3,
    a.year,
    'ATROCITY_PRECURSOR'::VARCHAR(50)      AS risk_code,
    a.risk_band,
    a.risk_rank,
    a.atrocity_precursor_score             AS risk_score,
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
        WHEN a.risk_band = 'BLACK'  THEN 'URGENT_CIVILIAN_PROTECTION_REVIEW'
        WHEN a.risk_band = 'RED'    THEN 'PREVENTION_ACTION_REQUIRED'
        WHEN a.risk_band = 'ORANGE' THEN 'EARLY_WARNING_REVIEW_REQUIRED'
        WHEN a.risk_band = 'YELLOW' THEN 'MONITORING_REQUIRED'
        ELSE 'NORMAL_MONITORING'
    END AS recommended_action,
    CASE
        WHEN a.risk_band = 'BLACK'  THEN 'Urgent civilian protection risk. Preventive review required. This is an early-warning signal, not a legal qualification.'
        WHEN a.risk_band = 'RED'    THEN 'Critical prevention risk requiring institutional review. This is not a legal qualification.'
        WHEN a.risk_band = 'ORANGE' THEN 'Early-warning atrocity precursor risk requiring reinforced monitoring.'
        WHEN a.risk_band = 'YELLOW' THEN 'Watchlist civilian protection risk requiring regular monitoring.'
        ELSE 'Low monitored civilian protection risk.'
    END AS public_narrative,
    CASE WHEN a.confidence_score < 0.40 THEN TRUE ELSE FALSE END AS confidence_review_required
FROM ma.v_p7i_amar_atrocity_precursor_engine a
LEFT JOIN ma.v_isa_early_warning_country_year cy
    ON cy.country_iso3 = a.country_iso3 AND cy.year = a.year;

COMMENT ON VIEW ma.v_p7i_amar_dashboard IS
'Sprint 12A -- Recree apres correction Correction B AMAR -- Mai 2026';

COMMIT;
