-- ============================================================
-- ma.v_p7j_recommendation_engine -- rebranchement sur mv_p7i_risk_source
-- 28 juillet 2026
-- ============================================================
-- Rebranche notre chaine (v_p7j_recommendation_engine, source de
-- notre catalogue pub.mv_isa_opportunity_catalog) sur la nouvelle
-- copie MATERIALISEE ma.mv_p7i_risk_source (3ms) au lieu de la vue
-- lente ma.v_p7i_risk_source (13,8s).
--
-- Vue normale (pas materialisee) -- CREATE OR REPLACE VIEW suffit,
-- aucun DROP, aucune dependance cassee. Un seul point d'accroche
-- identifie dans toute la definition (177 lignes) : le LEFT JOIN
-- dans le CTE "trajectory". Reste de la requete IDENTIQUE, copiee
-- fidelement depuis pg_get_viewdef.
--
-- AMAR/GENECO/precurseurs continuent d'utiliser l'ancienne vue lente
-- ma.v_p7i_risk_source, intacte -- aucun changement pour eux ce soir,
-- mutualisation future a leur rythme.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE OR REPLACE VIEW ma.v_p7j_recommendation_engine AS
WITH trajectory AS (
    SELECT
        p.country_iso3,
        p.year,
        p.pillar_code,
        p.isa_observed_score,
        p.sovereignty_observed_score,
        p.vulnerability_observed_score,
        p.avg_observation_confidence AS confidence,
        COALESCE(r.isa_trend_slope, 0::numeric) AS trend_slope,
        COALESCE(r.isa_volatility, 0::numeric) AS volatility,
        COALESCE(r.history_years, 0) AS history_years,
        COALESCE(r.forecast_trend_class, 'UNKNOWN'::text) AS forecast_trend_class,
        COALESCE(r.central_isa_delta, 0::numeric) AS central_isa_delta,
        COALESCE(r.ambitious_isa_delta, 0::numeric) AS ambitious_isa_delta,
        COALESCE(r.stress_isa_delta, 0::numeric) AS stress_isa_delta,
        COALESCE(r.central_simulation_decision, 'NO_SIMULATION'::text) AS central_simulation_decision,
        COALESCE(r.stress_simulation_decision, 'NO_SIMULATION'::text) AS stress_simulation_decision,
        COALESCE(r.swot_data_status, 'NO_COMPUTED_SWOT_ATTACHED'::text) AS swot_data_status,
        COALESCE(r.strategic_risk_score, 0::numeric) AS strategic_risk_score,
        COALESCE(r.strategic_upside_score, 0::numeric) AS strategic_upside_score
    FROM ma.v_isa_observed_scores_by_pillar p
    LEFT JOIN ma.mv_p7i_risk_source r ON r.country_iso3 = p.country_iso3::text AND r.year = p.year AND r.pillar_code = p.pillar_code::text
), classified AS (
    SELECT t.country_iso3,
        t.year,
        t.pillar_code,
        t.isa_observed_score,
        t.sovereignty_observed_score,
        t.vulnerability_observed_score,
        t.confidence,
        t.trend_slope,
        t.volatility,
        t.history_years,
        t.forecast_trend_class,
        t.central_isa_delta,
        t.ambitious_isa_delta,
        t.stress_isa_delta,
        t.central_simulation_decision,
        t.stress_simulation_decision,
        t.swot_data_status,
        t.strategic_risk_score,
        t.strategic_upside_score,
        CASE
            WHEN t.trend_slope > 0.003 THEN 'ACCELERATING'::text
            WHEN t.trend_slope > 0.001 THEN 'PROGRESSING'::text
            WHEN t.trend_slope >= '-0.001'::numeric THEN 'STABLE'::text
            WHEN t.trend_slope >= '-0.003'::numeric THEN 'DECLINING'::text
            ELSE 'CRITICAL'::text
        END AS trajectory_class,
        LEAST(1.0, GREATEST(0.0, (1.0 - t.isa_observed_score) * 0.40 +
            CASE
                WHEN t.trend_slope < 0::numeric THEN LEAST(1.0, abs(t.trend_slope) / 0.005)
                ELSE 0::numeric
            END * 0.35 + t.strategic_risk_score * 0.15 + LEAST(1.0, t.volatility / 0.02) * 0.10)) AS intervention_priority_score,
        CASE
            WHEN t.trend_slope > 0.003 AND t.strategic_upside_score > 0.30 THEN 'ACCELERATION_SIGNAL'::text
            WHEN t.trend_slope > 0.001 THEN 'PROGRESSION_SIGNAL'::text
            WHEN t.trend_slope >= '-0.001'::numeric AND t.trend_slope <= 0.001 THEN 'STABILITY_SIGNAL'::text
            WHEN t.trend_slope < '-0.001'::numeric AND t.strategic_risk_score > 0.40 THEN 'DETERIORATION_ALERT'::text
            ELSE 'DECLINE_SIGNAL'::text
        END AS trajectory_signal
    FROM trajectory t
), with_policy AS (
    SELECT c.country_iso3,
        c.year,
        c.pillar_code,
        c.isa_observed_score,
        c.sovereignty_observed_score,
        c.vulnerability_observed_score,
        c.confidence,
        c.trend_slope,
        c.volatility,
        c.history_years,
        c.forecast_trend_class,
        c.central_isa_delta,
        c.ambitious_isa_delta,
        c.stress_isa_delta,
        c.central_simulation_decision,
        c.stress_simulation_decision,
        c.swot_data_status,
        c.strategic_risk_score,
        c.strategic_upside_score,
        c.trajectory_class,
        c.intervention_priority_score,
        c.trajectory_signal,
        COALESCE(pol.role_label, 'Trajectoire a qualifier'::text) AS trajectory_label,
        COALESCE(pol.open_data_allowed, true) AS open_data_allowed,
        COALESCE(pol.premium_allowed, false) AS premium_allowed,
        COALESCE(pol.predictive_required, false) AS predictive_required,
        COALESCE(pol.notes, ''::text) AS policy_notes
    FROM classified c
    LEFT JOIN rf.isa_strategic_diagnostic_policy pol ON pol.diagnostic_role::text = c.trajectory_class
), with_family AS (
    SELECT wp.country_iso3,
        wp.year,
        wp.pillar_code,
        wp.isa_observed_score,
        wp.sovereignty_observed_score,
        wp.vulnerability_observed_score,
        wp.confidence,
        wp.trend_slope,
        wp.volatility,
        wp.history_years,
        wp.forecast_trend_class,
        wp.central_isa_delta,
        wp.ambitious_isa_delta,
        wp.stress_isa_delta,
        wp.central_simulation_decision,
        wp.stress_simulation_decision,
        wp.swot_data_status,
        wp.strategic_risk_score,
        wp.strategic_upside_score,
        wp.trajectory_class,
        wp.intervention_priority_score,
        wp.trajectory_signal,
        wp.trajectory_label,
        wp.open_data_allowed,
        wp.premium_allowed,
        wp.predictive_required,
        wp.policy_notes,
        COALESCE(f.intervention_family_code, 'SOVEREIGN_DEVELOPMENT'::character varying) AS intervention_family_code,
        COALESCE(f.intervention_family_label, 'Developpement souverain'::text) AS intervention_family_label,
        COALESCE(f.strategic_objective, 'Renforcer la souverainete observee.'::text) AS strategic_objective,
        COALESCE(f.consultation_theme, 'Consultation souveraine.'::text) AS consultation_theme
    FROM with_policy wp
    LEFT JOIN rf.isa_candidate_intervention_family f ON f.pillar_code::text = wp.pillar_code::text
)
SELECT country_iso3,
    year,
    pillar_code,
    trajectory_class,
    trajectory_label,
    trajectory_signal,
    intervention_family_code,
    intervention_family_label,
    strategic_objective,
    open_data_allowed,
    premium_allowed,
    predictive_required,
    round(isa_observed_score, 4) AS isa_observed_score,
    round(sovereignty_observed_score, 4) AS sovereignty_observed_score,
    round(vulnerability_observed_score, 4) AS vulnerability_observed_score,
    round(trend_slope, 5) AS trend_slope,
    round(volatility, 5) AS volatility,
    history_years,
    round(confidence, 4) AS confidence,
    forecast_trend_class,
    round(intervention_priority_score, 4) AS intervention_priority_score,
    swot_data_status,
    round(strategic_risk_score, 4) AS strategic_risk_score,
    round(strategic_upside_score, 4) AS strategic_upside_score,
    consultation_theme,
    policy_notes,
    round(central_isa_delta, 4) AS central_isa_delta,
    round(ambitious_isa_delta, 4) AS ambitious_isa_delta,
    round(stress_isa_delta, 4) AS stress_isa_delta,
    central_simulation_decision,
    stress_simulation_decision,
    CASE
        WHEN intervention_priority_score >= 0.75 THEN 'PRIORITY_CRITICAL'::text
        WHEN intervention_priority_score >= 0.55 THEN 'PRIORITY_HIGH'::text
        WHEN intervention_priority_score >= 0.35 THEN 'PRIORITY_STANDARD'::text
        ELSE 'PRIORITY_MONITOR'::text
    END AS intervention_priority_class,
    CASE trajectory_class
        WHEN 'ACCELERATING'::text THEN 'CONSOLIDATE_AND_SCALE'::text
        WHEN 'PROGRESSING'::text THEN 'SUSTAIN_AND_OPTIMIZE'::text
        WHEN 'STABLE'::text THEN 'IDENTIFY_UNLOCK_LEVERS'::text
        WHEN 'DECLINING'::text THEN 'DIAGNOSE_AND_CORRECT'::text
        WHEN 'CRITICAL'::text THEN 'URGENT_INTERVENTION_REQUIRED'::text
        ELSE 'ASSESS_TRAJECTORY'::text
    END AS recommended_action
FROM with_family;

COMMIT;

-- Verification post-execution -- mesure du temps reel
\timing on
SELECT COUNT(*) FROM ma.v_p7j_recommendation_engine WHERE year = (SELECT max(year) FROM ma.v_p7j_recommendation_engine);
