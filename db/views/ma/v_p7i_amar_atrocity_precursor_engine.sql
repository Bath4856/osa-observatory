-- ============================================================
-- OSA / ISA — P7I-AMAR Atrocity Precursor Engine
-- Production merge pack v2
-- Uses EXISTING ma.v_p7i_risk_source columns.
-- No replacement of P7I Core.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7i_amar_atrocity_precursor_engine AS
WITH base AS (
    SELECT
        country_iso3,
        year,
        pillar_code,

        COALESCE(weakness_score, 0)::numeric AS weakness_score,
        COALESCE(threat_score, 0)::numeric AS threat_score,
        COALESCE(strategic_risk_score, 0)::numeric AS strategic_risk_score,
        COALESCE(vulnerability_observed_score, 0)::numeric AS vulnerability_observed_score,
        COALESCE(resilience_observed_score, 0)::numeric AS resilience_observed_score,
        COALESCE(observation_confidence, 0)::numeric AS observation_confidence,
        COALESCE(forecast_observation_confidence, observation_confidence, 0)::numeric AS forecast_observation_confidence,
        COALESCE(isa_trend_slope, 0)::numeric AS isa_trend_slope,
        COALESCE(isa_volatility, 0)::numeric AS isa_volatility,
        COALESCE(stress_isa_delta, 0)::numeric AS stress_isa_delta,
        COALESCE(stress_simulation_confidence, 0)::numeric AS stress_simulation_confidence,
        COALESCE(central_isa_delta, 0)::numeric AS central_isa_delta,
        COALESCE(forecast_trend_status, 'UNKNOWN')::text AS forecast_trend_status,
        COALESCE(forecast_blocking_reason, 'NONE')::text AS forecast_blocking_reason,
        COALESCE(strategic_attention_class, 'UNCLASSIFIED')::text AS strategic_attention_class,
        COALESCE(strategic_diagnostic_role, 'UNCLASSIFIED')::text AS strategic_diagnostic_role,

        LEAST(1.000, GREATEST(
            0.000,
            COALESCE(threat_score, 0),
            COALESCE(strategic_risk_score, 0),
            COALESCE(vulnerability_observed_score, 0),
            ABS(COALESCE(stress_isa_delta, 0))
        ))::numeric AS amar_risk_component
    FROM ma.v_p7i_risk_source
),

-- Weighted domain scores, normalized by available pillar weights.
domain_scores AS (
    SELECT
        country_iso3,
        year,

        -- Structural fragility: PHUM 35, PECO 20, PGEO 25, PMON 20
        COALESCE(
            SUM(CASE pillar_code
                WHEN 'PHUM' THEN amar_risk_component * 0.35
                WHEN 'PECO' THEN amar_risk_component * 0.20
                WHEN 'PGEO' THEN amar_risk_component * 0.25
                WHEN 'PMON' THEN amar_risk_component * 0.20
                ELSE 0 END)
            /
            NULLIF(SUM(CASE pillar_code
                WHEN 'PHUM' THEN 0.35
                WHEN 'PECO' THEN 0.20
                WHEN 'PGEO' THEN 0.25
                WHEN 'PMON' THEN 0.20
                ELSE 0 END), 0),
            0
        )::numeric AS structural_fragility_score,

        -- Conflict escalation: PMIL 45, PGEO 35, PTRA 20
        COALESCE(
            SUM(CASE pillar_code
                WHEN 'PMIL' THEN amar_risk_component * 0.45
                WHEN 'PGEO' THEN amar_risk_component * 0.35
                WHEN 'PTRA' THEN amar_risk_component * 0.20
                ELSE 0 END)
            /
            NULLIF(SUM(CASE pillar_code
                WHEN 'PMIL' THEN 0.45
                WHEN 'PGEO' THEN 0.35
                WHEN 'PTRA' THEN 0.20
                ELSE 0 END), 0),
            0
        )::numeric AS conflict_escalation_score,

        -- Governance breakdown: PGEO 50, PECO 20, PNUM 15, PMON 15
        COALESCE(
            SUM(CASE pillar_code
                WHEN 'PGEO' THEN amar_risk_component * 0.50
                WHEN 'PECO' THEN amar_risk_component * 0.20
                WHEN 'PNUM' THEN amar_risk_component * 0.15
                WHEN 'PMON' THEN amar_risk_component * 0.15
                ELSE 0 END)
            /
            NULLIF(SUM(CASE pillar_code
                WHEN 'PGEO' THEN 0.50
                WHEN 'PECO' THEN 0.20
                WHEN 'PNUM' THEN 0.15
                WHEN 'PMON' THEN 0.15
                ELSE 0 END), 0),
            0
        )::numeric AS governance_breakdown_score,

        -- Humanitarian stress: PHUM 45, PENV 30, PECO 25
        COALESCE(
            SUM(CASE pillar_code
                WHEN 'PHUM' THEN amar_risk_component * 0.45
                WHEN 'PENV' THEN amar_risk_component * 0.30
                WHEN 'PECO' THEN amar_risk_component * 0.25
                ELSE 0 END)
            /
            NULLIF(SUM(CASE pillar_code
                WHEN 'PHUM' THEN 0.45
                WHEN 'PENV' THEN 0.30
                WHEN 'PECO' THEN 0.25
                ELSE 0 END), 0),
            0
        )::numeric AS humanitarian_stress_score,

        -- Resource conflict: PMIN 50, PRES 30, PTRA 20
        COALESCE(
            SUM(CASE pillar_code
                WHEN 'PMIN' THEN amar_risk_component * 0.50
                WHEN 'PRES' THEN amar_risk_component * 0.30
                WHEN 'PTRA' THEN amar_risk_component * 0.20
                ELSE 0 END)
            /
            NULLIF(SUM(CASE pillar_code
                WHEN 'PMIN' THEN 0.50
                WHEN 'PRES' THEN 0.30
                WHEN 'PTRA' THEN 0.20
                ELSE 0 END), 0),
            0
        )::numeric AS resource_conflict_score,

        -- Information polarization proxy: PNUM 60, PGEO 40
        COALESCE(
            SUM(CASE pillar_code
                WHEN 'PNUM' THEN amar_risk_component * 0.60
                WHEN 'PGEO' THEN amar_risk_component * 0.40
                ELSE 0 END)
            /
            NULLIF(SUM(CASE pillar_code
                WHEN 'PNUM' THEN 0.60
                WHEN 'PGEO' THEN 0.40
                ELSE 0 END), 0),
            0
        )::numeric AS information_polarization_score,

        AVG(ABS(isa_trend_slope))::numeric AS avg_abs_isa_trend_slope,
        AVG(isa_volatility)::numeric AS avg_isa_volatility,
        AVG(ABS(stress_isa_delta))::numeric AS avg_stress_delta,
        AVG(observation_confidence)::numeric AS avg_observation_confidence,
        AVG(forecast_observation_confidence)::numeric AS avg_forecast_observation_confidence,
        AVG(stress_simulation_confidence)::numeric AS avg_stress_simulation_confidence,
        COUNT(*)::integer AS nb_pillars_monitored
    FROM base
    GROUP BY country_iso3, year
),

scored AS (
    SELECT
        country_iso3,
        year,
        nb_pillars_monitored,

        LEAST(1.000, GREATEST(0.000, COALESCE(structural_fragility_score, 0)))::numeric AS structural_fragility_score,
        LEAST(1.000, GREATEST(0.000, COALESCE(conflict_escalation_score, 0)))::numeric AS conflict_escalation_score,
        LEAST(1.000, GREATEST(0.000, COALESCE(governance_breakdown_score, 0)))::numeric AS governance_breakdown_score,
        LEAST(1.000, GREATEST(0.000, COALESCE(humanitarian_stress_score, 0)))::numeric AS humanitarian_stress_score,
        LEAST(1.000, GREATEST(0.000, COALESCE(resource_conflict_score, 0)))::numeric AS resource_conflict_score,
        LEAST(1.000, GREATEST(0.000, COALESCE(information_polarization_score, 0)))::numeric AS information_polarization_score,

        COALESCE(avg_abs_isa_trend_slope, 0)::numeric AS avg_abs_isa_trend_slope,
        COALESCE(avg_isa_volatility, 0)::numeric AS avg_isa_volatility,
        COALESCE(avg_stress_delta, 0)::numeric AS avg_stress_delta,

        ROUND(
            LEAST(1.000, GREATEST(0.000,
                (
                    COALESCE(structural_fragility_score, 0) * 0.20 +
                    COALESCE(conflict_escalation_score, 0) * 0.25 +
                    COALESCE(governance_breakdown_score, 0) * 0.20 +
                    COALESCE(humanitarian_stress_score, 0) * 0.15 +
                    COALESCE(resource_conflict_score, 0) * 0.10 +
                    COALESCE(information_polarization_score, 0) * 0.10
                )
                + (LEAST(1.000, COALESCE(avg_stress_delta, 0)) * 0.10)
                + (LEAST(1.000, COALESCE(avg_isa_volatility, 0)) * 0.05)
            )),
            3
        )::numeric(6,3) AS atrocity_precursor_score,

        ROUND(
            LEAST(1.000, GREATEST(0.000,
                COALESCE(avg_observation_confidence, 0) * 0.50 +
                COALESCE(avg_forecast_observation_confidence, 0) * 0.30 +
                COALESCE(avg_stress_simulation_confidence, 0) * 0.20
            )),
            3
        )::numeric(6,3) AS confidence_score
    FROM domain_scores
)

SELECT
    country_iso3,
    year,
    nb_pillars_monitored,

    ROUND(structural_fragility_score, 3)::numeric(6,3) AS structural_fragility_score,
    ROUND(conflict_escalation_score, 3)::numeric(6,3) AS conflict_escalation_score,
    ROUND(governance_breakdown_score, 3)::numeric(6,3) AS governance_breakdown_score,
    ROUND(humanitarian_stress_score, 3)::numeric(6,3) AS humanitarian_stress_score,
    ROUND(resource_conflict_score, 3)::numeric(6,3) AS resource_conflict_score,
    ROUND(information_polarization_score, 3)::numeric(6,3) AS information_polarization_score,

    ROUND(avg_abs_isa_trend_slope, 3)::numeric(8,3) AS avg_abs_isa_trend_slope,
    ROUND(avg_isa_volatility, 3)::numeric(8,3) AS avg_isa_volatility,
    ROUND(avg_stress_delta, 3)::numeric(8,3) AS avg_stress_delta,

    atrocity_precursor_score,
    confidence_score,

    CASE
        WHEN atrocity_precursor_score < 0.25 THEN 'GREEN'
        WHEN atrocity_precursor_score < 0.45 THEN 'YELLOW'
        WHEN atrocity_precursor_score < 0.65 THEN 'ORANGE'
        WHEN atrocity_precursor_score < 0.80 THEN 'RED'
        ELSE 'BLACK'
    END AS risk_band,

    CASE
        WHEN atrocity_precursor_score < 0.25 THEN 1
        WHEN atrocity_precursor_score < 0.45 THEN 2
        WHEN atrocity_precursor_score < 0.65 THEN 3
        WHEN atrocity_precursor_score < 0.80 THEN 4
        ELSE 5
    END AS risk_rank,

    CASE
        WHEN atrocity_precursor_score < 0.25 THEN 'Low monitored civilian protection risk'
        WHEN atrocity_precursor_score < 0.45 THEN 'Watchlist civilian protection risk'
        WHEN atrocity_precursor_score < 0.65 THEN 'Early-warning atrocity precursor risk'
        WHEN atrocity_precursor_score < 0.80 THEN 'Critical prevention risk'
        ELSE 'Urgent civilian protection risk'
    END AS risk_interpretation,

    CASE
        WHEN confidence_score < 0.40 THEN 'LOW_CONFIDENCE_REVIEW_REQUIRED'
        WHEN confidence_score < 0.65 THEN 'CONTROLLED_CONFIDENCE'
        ELSE 'STRONG_CONFIDENCE'
    END AS confidence_class
FROM scored;
