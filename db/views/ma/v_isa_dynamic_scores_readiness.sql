-- ============================================================
-- OSA / ISA — P7D
-- View: ma.v_isa_dynamic_scores_readiness
-- Purpose:
--   Aggregate P7D dynamic score components by pillar and semantic family.
--   This is a readiness view, not the final country/year score table.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_dynamic_scores_readiness AS

WITH grouped AS (
    SELECT
        pillar_code,
        semantic_code,
        COUNT(*) AS nb_indicators,

        ROUND(AVG(dynamic_isa_score_component), 3) AS avg_dynamic_isa_score,
        ROUND(AVG(dynamic_sovereignty_score_component), 3) AS avg_dynamic_sovereignty_score,
        ROUND(AVG(dynamic_vulnerability_score_component), 3) AS avg_dynamic_vulnerability_score,
        ROUND(AVG(dynamic_resilience_score_component), 3) AS avg_dynamic_resilience_score,
        ROUND(AVG(dynamic_forecast_score_component), 3) AS avg_dynamic_forecast_score,
        ROUND(AVG(dynamic_ml_score_component), 3) AS avg_dynamic_ml_score,

        SUM(CASE WHEN dynamic_score_class = 'DYNAMIC_SCORE_CORE_STRONG' THEN 1 ELSE 0 END) AS nb_score_core_strong,
        SUM(CASE WHEN dynamic_score_class = 'DYNAMIC_SCORE_CORE_CONTROLLED' THEN 1 ELSE 0 END) AS nb_score_core_controlled,
        SUM(CASE WHEN dynamic_score_class = 'DYNAMIC_SCORE_LOCKED_GAP' THEN 1 ELSE 0 END) AS nb_score_locked_gap,
        SUM(CASE WHEN dynamic_score_class = 'DYNAMIC_SCORE_VULNERABILITY_SIGNAL' THEN 1 ELSE 0 END) AS nb_score_vulnerability_signal,
        SUM(CASE WHEN dynamic_score_forecast_class = 'SCORE_FORECAST_DISABLED' THEN 1 ELSE 0 END) AS nb_score_forecast_disabled,
        SUM(CASE WHEN dynamic_score_decision = 'USE_IN_DYNAMIC_ISA_SCORE' THEN 1 ELSE 0 END) AS nb_use_dynamic_isa_score,
        SUM(CASE WHEN dynamic_score_decision = 'USE_IN_DYNAMIC_VULNERABILITY_SCORE' THEN 1 ELSE 0 END) AS nb_use_dynamic_vulnerability_score

    FROM ma.v_dynamic_scores_engine
    GROUP BY pillar_code, semantic_code
)
SELECT
    *,
    CASE
        WHEN nb_score_locked_gap > 0
            THEN 'DYNAMIC_SCORE_NEEDS_GAP_REVIEW'
        WHEN nb_score_vulnerability_signal > 0
         AND avg_dynamic_vulnerability_score >= 0.750
            THEN 'DYNAMIC_SCORE_VULNERABILITY_DOMINANT'
        WHEN avg_dynamic_isa_score >= 0.650
         AND nb_use_dynamic_isa_score > 0
            THEN 'DYNAMIC_SCORE_READY_STRONG'
        WHEN avg_dynamic_isa_score >= 0.350
         AND nb_use_dynamic_isa_score > 0
            THEN 'DYNAMIC_SCORE_READY_CONTROLLED'
        WHEN avg_dynamic_vulnerability_score >= 0.550
            THEN 'DYNAMIC_SCORE_RISK_SIGNAL'
        ELSE 'DYNAMIC_SCORE_CONTEXTUAL'
    END AS dynamic_scores_readiness_status
FROM grouped;
