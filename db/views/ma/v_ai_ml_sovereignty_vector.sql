-- ============================================================
-- OSA / ISA — P6
-- Vue : ma.v_ai_ml_sovereignty_vector
-- Rôle :
--   produire le vecteur IA/ML multidimensionnel :
--   signal + confiance + couverture + vulnérabilité + SWOT L3
-- ============================================================

CREATE OR REPLACE VIEW ma.v_ai_ml_sovereignty_vector AS

WITH signal_by_pillar AS (
    SELECT
        ste.country_iso3,
        ste.year::SMALLINT AS obs_year,
        ste.pillar_code,

        ROUND(AVG(COALESCE(ste.processed_value, ste.raw_value, 0))::NUMERIC, 3) AS raw_signal_score,

        ROUND(AVG(ste.signal_trust_score), 3)          AS trust_score,
        ROUND(AVG(ste.coverage_score), 3)              AS coverage_score,
        ROUND(AVG(ste.mapping_quality_score), 3)       AS mapping_quality_score,
        ROUND(AVG(ste.mapping_maturity_score), 3)      AS mapping_maturity_score,
        ROUND(AVG(ste.signal_vulnerability_score), 3)  AS vulnerability_score,

        COUNT(*) AS signal_count,

        COUNT(*) FILTER (WHERE ste.signal_status = 'TRUSTED_SIGNAL') AS trusted_signal_count,
        COUNT(*) FILTER (WHERE ste.signal_status = 'WEAK_BUT_INFORMATIVE') AS weak_but_informative_count,
        COUNT(*) FILTER (WHERE ste.signal_status IN ('STRUCTURAL_GAP', 'NATURE_GAP')) AS gap_signal_count,
        COUNT(*) FILTER (WHERE ste.is_estimated = TRUE) AS estimated_signal_count

    FROM ma.v_signal_trust_engine ste
    GROUP BY
        ste.country_iso3,
        ste.year,
        ste.pillar_code
),

gap_by_pillar AS (
    SELECT
        sge.country_iso3,
        sge.year::SMALLINT AS obs_year,
        sge.pillar_code,

        sge.structural_gap_score,
        sge.structural_gap_class,

        sge.nb_structural_gaps,
        sge.nb_nature_gaps,
        sge.nb_physical_estimation_risks,
        sge.nb_low_coverage_signals,
        sge.nb_estimated_signals

    FROM ma.v_structural_gap_engine sge
),

swot_by_pillar AS (
    SELECT
        sw.country_iso3,
        sw.obs_year,
        sw.pillar_code,

        sw.force_score,
        sw.opportunity_score,
        sw.weakness_score,
        sw.threat_score,
        sw.swot_balance_score,
        sw.swot_confidence,
        sw.swot_signal_class,

        sw.force_count,
        sw.opportunity_count,
        sw.weakness_count,
        sw.threat_count,
        sw.total_swot_signals

    FROM ma.v_swot_vectors sw
),

combined AS (
    SELECT
        s.country_iso3,
        s.obs_year,
        s.pillar_code,

        COALESCE(s.raw_signal_score, 0)           AS raw_signal_score,
        COALESCE(s.trust_score, 0)                AS trust_score,
        COALESCE(s.coverage_score, 0)             AS coverage_score,
        COALESCE(s.mapping_quality_score, 0)      AS mapping_quality_score,
        COALESCE(s.mapping_maturity_score, 0)     AS mapping_maturity_score,
        COALESCE(s.vulnerability_score, 0)        AS vulnerability_score,

        COALESCE(s.signal_count, 0)               AS signal_count,
        COALESCE(s.trusted_signal_count, 0)       AS trusted_signal_count,
        COALESCE(s.weak_but_informative_count, 0) AS weak_but_informative_count,
        COALESCE(s.gap_signal_count, 0)           AS gap_signal_count,
        COALESCE(s.estimated_signal_count, 0)     AS estimated_signal_count,

        COALESCE(g.structural_gap_score, 0)       AS structural_gap_score,
        COALESCE(g.structural_gap_class, 'CONTROLLED_SIGNAL') AS structural_gap_class,

        COALESCE(g.nb_structural_gaps, 0)         AS structural_gap_count,
        COALESCE(g.nb_nature_gaps, 0)             AS nature_gap_count,
        COALESCE(g.nb_physical_estimation_risks, 0) AS physical_estimation_risk_count,
        COALESCE(g.nb_low_coverage_signals, 0)    AS low_coverage_signal_count,
        COALESCE(g.nb_estimated_signals, 0)       AS gap_engine_estimated_signal_count,

        COALESCE(sw.force_score, 0)               AS force_score,
        COALESCE(sw.opportunity_score, 0)         AS opportunity_score,
        COALESCE(sw.weakness_score, 0)            AS weakness_score,
        COALESCE(sw.threat_score, 0)              AS threat_score,
        COALESCE(sw.swot_balance_score, 0)        AS swot_balance_score,
        COALESCE(sw.swot_confidence, 0)           AS swot_confidence,
        COALESCE(sw.swot_signal_class, 'NO_SWOT_SIGNAL') AS swot_signal_class,

        COALESCE(sw.force_count, 0)               AS force_count,
        COALESCE(sw.opportunity_count, 0)         AS opportunity_count,
        COALESCE(sw.weakness_count, 0)            AS weakness_count,
        COALESCE(sw.threat_count, 0)              AS threat_count,
        COALESCE(sw.total_swot_signals, 0)        AS total_swot_signals

    FROM signal_by_pillar s

    LEFT JOIN gap_by_pillar g
        ON g.country_iso3 = s.country_iso3
       AND g.obs_year     = s.obs_year
       AND g.pillar_code  = s.pillar_code

    LEFT JOIN swot_by_pillar sw
        ON sw.country_iso3 = s.country_iso3
       AND sw.obs_year     = s.obs_year
       AND sw.pillar_code  = s.pillar_code
),

scored AS (
    SELECT
        combined.*,

        ROUND(
            (
                (trust_score * 0.25)
              + (coverage_score * 0.15)
              + (mapping_quality_score * 0.15)
              + (mapping_maturity_score * 0.15)
              + ((1 - vulnerability_score) * 0.15)
              + ((1 - structural_gap_score) * 0.15)
            )::NUMERIC,
            3
        ) AS ai_ml_readiness_score

    FROM combined
)

SELECT
    country_iso3,
    obs_year,
    pillar_code,

    raw_signal_score,
    trust_score,
    coverage_score,
    mapping_quality_score,
    mapping_maturity_score,
    vulnerability_score,
    structural_gap_score,

    force_score,
    opportunity_score,
    weakness_score,
    threat_score,
    swot_balance_score,
    swot_confidence,

    signal_count,
    trusted_signal_count,
    weak_but_informative_count,
    gap_signal_count,
    estimated_signal_count,

    structural_gap_count,
    nature_gap_count,
    physical_estimation_risk_count,
    low_coverage_signal_count,
    gap_engine_estimated_signal_count,

    force_count,
    opportunity_count,
    weakness_count,
    threat_count,
    total_swot_signals,

    ai_ml_readiness_score,

    CASE
        WHEN structural_gap_score >= 0.70
          AND weakness_score >= 0.60
          AND threat_score >= 0.60
            THEN 'STRUCTURAL_SOVEREIGNTY_RISK'

        WHEN vulnerability_score >= 0.70
            THEN 'HIGH_VULNERABILITY_SIGNAL'

        WHEN trust_score < 0.40
          AND coverage_score < 0.40
            THEN 'LOW_TRUST_BUT_INFORMATIVE'

        WHEN swot_signal_class = 'STRATEGIC_LEVERAGE'
            THEN 'STRATEGIC_LEVERAGE_SIGNAL'

        WHEN ai_ml_readiness_score >= 0.75
            THEN 'MODEL_READY_STRONG'

        WHEN ai_ml_readiness_score >= 0.55
            THEN 'MODEL_READY_PARTIAL'

        ELSE 'OBSERVATION_REQUIRED'
    END AS ai_ml_signal_class,

    structural_gap_class,
    swot_signal_class

FROM scored;