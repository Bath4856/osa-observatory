-- ============================================================
-- OSA Observatory -- Sprint 12
-- P7J -- Moteur de recommandations souveraines
-- Vision trajectoire + modele economique autofinancement
--
-- Architecture :
--   Couche 0 : Open data  -- classe trajectoire + pilier + famille
--   Couche 1 : Affilie    -- action souveraine + score + pente
--   Couche 2 : Premium    -- simulation + IC + alerte AMAR
--
-- Classification trajectoire (5 classes) :
--   ACCELERATING  : slope >  0.003
--   PROGRESSING   : slope    0.001 .. 0.003
--   STABLE        : slope   -0.001 .. 0.001
--   DECLINING     : slope   -0.003 ..-0.001
--   CRITICAL      : slope < -0.003
-- ============================================================

BEGIN;

-- ── 1. Mise a jour rf.isa_strategic_diagnostic_policy ────────
-- Les 5 roles existants sont renommes pour coller
-- a la vision trajectoire. open_data / premium / predictive
-- sont recalibres selon le modele economique OSA.

-- Supprimer les anciennes entrees et reinserrer
DELETE FROM rf.isa_strategic_diagnostic_policy;

INSERT INTO rf.isa_strategic_diagnostic_policy
  (diagnostic_role, role_label, open_data_allowed,
   premium_allowed, predictive_required, notes)
VALUES
  ('ACCELERATING',
   'Trajectoire ascendante',
   TRUE, FALSE, FALSE,
   'Score en hausse acceleree. Consolidation et capitalisation recommandees.'),
  ('PROGRESSING',
   'Trajectoire progressive',
   TRUE, FALSE, FALSE,
   'Score en progression moderee. Maintien et optimisation recommandes.'),
  ('STABLE',
   'Trajectoire stable',
   TRUE, FALSE, FALSE,
   'Score stable. Identification des leviers de deblocage recommandee.'),
  ('DECLINING',
   'Trajectoire declinante',
   TRUE, TRUE, FALSE,
   'Score en baisse. Analyse des facteurs de deterioration et plan correctif.'),
  ('CRITICAL',
   'Trajectoire critique',
   TRUE, TRUE, TRUE,
   'Score en baisse acceleree. Intervention prioritaire recommandee.')
ON CONFLICT DO NOTHING;

-- ── 2. Vue P7J core -- moteur trajectoire ────────────────────
CREATE OR REPLACE VIEW ma.v_p7j_recommendation_engine AS

WITH trajectory AS (
    -- Score et pente par pays/pilier/annee
    SELECT
        p.country_iso3,
        p.year,
        p.pillar_code,
        p.isa_observed_score,
        p.sovereignty_observed_score,
        p.vulnerability_observed_score,
        p.avg_observation_confidence          AS confidence,
        COALESCE(r.isa_trend_slope, 0)        AS trend_slope,
        COALESCE(r.isa_volatility, 0)         AS volatility,
        COALESCE(r.history_years, 0)          AS history_years,
        COALESCE(r.forecast_trend_class,
                 'UNKNOWN')                   AS forecast_trend_class,
        COALESCE(r.central_isa_delta, 0)      AS central_isa_delta,
        COALESCE(r.ambitious_isa_delta, 0)    AS ambitious_isa_delta,
        COALESCE(r.stress_isa_delta, 0)       AS stress_isa_delta,
        COALESCE(r.central_simulation_decision,
                 'NO_SIMULATION')             AS central_simulation_decision,
        COALESCE(r.stress_simulation_decision,
                 'NO_SIMULATION')             AS stress_simulation_decision,
        COALESCE(r.swot_data_status,
                 'NO_COMPUTED_SWOT_ATTACHED') AS swot_data_status,
        COALESCE(r.strategic_risk_score, 0)   AS strategic_risk_score,
        COALESCE(r.strategic_upside_score, 0) AS strategic_upside_score
    FROM ma.v_isa_observed_scores_by_pillar p
    LEFT JOIN ma.v_p7i_risk_source r
        ON  r.country_iso3 = p.country_iso3
        AND r.year         = p.year
        AND r.pillar_code  = p.pillar_code
),

classified AS (
    SELECT
        t.*,
        -- Classification trajectoire (5 classes absolues)
        CASE
            WHEN t.trend_slope >  0.003 THEN 'ACCELERATING'
            WHEN t.trend_slope >  0.001 THEN 'PROGRESSING'
            WHEN t.trend_slope >= -0.001 THEN 'STABLE'
            WHEN t.trend_slope >= -0.003 THEN 'DECLINING'
            ELSE                              'CRITICAL'
        END AS trajectory_class,

        -- Priorite d'intervention (0-1)
        LEAST(1.0, GREATEST(0.0,
            -- Score bas = priorite elevee
            (1.0 - t.isa_observed_score) * 0.40
            -- Pente negative = priorite elevee
            + CASE WHEN t.trend_slope < 0
                   THEN LEAST(1.0, ABS(t.trend_slope) / 0.005)
                   ELSE 0 END * 0.35
            -- Risque strategique
            + t.strategic_risk_score * 0.15
            -- Volatilite
            + LEAST(1.0, t.volatility / 0.02) * 0.10
        )) AS intervention_priority_score,

        -- Signal d'acceleration positive
        CASE
            WHEN t.trend_slope > 0.003
             AND t.strategic_upside_score > 0.30 THEN 'ACCELERATION_SIGNAL'
            WHEN t.trend_slope > 0.001           THEN 'PROGRESSION_SIGNAL'
            WHEN t.trend_slope BETWEEN -0.001
                                    AND  0.001   THEN 'STABILITY_SIGNAL'
            WHEN t.trend_slope < -0.001
             AND t.strategic_risk_score > 0.40   THEN 'DETERIORATION_ALERT'
            ELSE                                      'DECLINE_SIGNAL'
        END AS trajectory_signal

    FROM trajectory t
),

with_policy AS (
    SELECT
        c.*,
        COALESCE(pol.role_label,
                 'Trajectoire a qualifier') AS trajectory_label,
        COALESCE(pol.open_data_allowed,
                 TRUE)                      AS open_data_allowed,
        COALESCE(pol.premium_allowed,
                 FALSE)                     AS premium_allowed,
        COALESCE(pol.predictive_required,
                 FALSE)                     AS predictive_required,
        COALESCE(pol.notes, '')             AS policy_notes
    FROM classified c
    LEFT JOIN rf.isa_strategic_diagnostic_policy pol
        ON pol.diagnostic_role = c.trajectory_class
),

with_family AS (
    SELECT
        wp.*,
        COALESCE(f.intervention_family_code,
                 'SOVEREIGN_DEVELOPMENT')        AS intervention_family_code,
        COALESCE(f.intervention_family_label,
                 'Developpement souverain')      AS intervention_family_label,
        COALESCE(f.strategic_objective,
                 'Renforcer la souverainete observee.') AS strategic_objective,
        COALESCE(f.consultation_theme,
                 'Consultation souveraine.')     AS consultation_theme
    FROM with_policy wp
    LEFT JOIN rf.isa_candidate_intervention_family f
        ON f.pillar_code = wp.pillar_code
)

SELECT
    -- ── Identifiants ──────────────────────────────────────────
    country_iso3,
    year,
    pillar_code,

    -- ── COUCHE 0 : Open data ──────────────────────────────────
    trajectory_class,
    trajectory_label,
    trajectory_signal,
    intervention_family_code,
    intervention_family_label,
    strategic_objective,
    open_data_allowed,
    premium_allowed,
    predictive_required,

    -- ── COUCHE 1 : Affilie ────────────────────────────────────
    ROUND(isa_observed_score::numeric, 4)          AS isa_observed_score,
    ROUND(sovereignty_observed_score::numeric, 4)  AS sovereignty_observed_score,
    ROUND(vulnerability_observed_score::numeric, 4) AS vulnerability_observed_score,
    ROUND(trend_slope::numeric, 5)                 AS trend_slope,
    ROUND(volatility::numeric, 5)                  AS volatility,
    history_years,
    ROUND(confidence::numeric, 4)                  AS confidence,
    forecast_trend_class,
    ROUND(intervention_priority_score::numeric, 4) AS intervention_priority_score,
    swot_data_status,
    ROUND(strategic_risk_score::numeric, 4)        AS strategic_risk_score,
    ROUND(strategic_upside_score::numeric, 4)      AS strategic_upside_score,
    consultation_theme,
    policy_notes,

    -- ── COUCHE 2 : Premium ────────────────────────────────────
    ROUND(central_isa_delta::numeric, 4)           AS central_isa_delta,
    ROUND(ambitious_isa_delta::numeric, 4)         AS ambitious_isa_delta,
    ROUND(stress_isa_delta::numeric, 4)            AS stress_isa_delta,
    central_simulation_decision,
    stress_simulation_decision,

    -- ── Classification priorite ───────────────────────────────
    CASE
        WHEN intervention_priority_score >= 0.75 THEN 'PRIORITY_CRITICAL'
        WHEN intervention_priority_score >= 0.55 THEN 'PRIORITY_HIGH'
        WHEN intervention_priority_score >= 0.35 THEN 'PRIORITY_STANDARD'
        ELSE                                          'PRIORITY_MONITOR'
    END AS intervention_priority_class,

    -- ── Action recommandee (Couche 1) ─────────────────────────
    CASE trajectory_class
        WHEN 'ACCELERATING' THEN 'CONSOLIDATE_AND_SCALE'
        WHEN 'PROGRESSING'  THEN 'SUSTAIN_AND_OPTIMIZE'
        WHEN 'STABLE'       THEN 'IDENTIFY_UNLOCK_LEVERS'
        WHEN 'DECLINING'    THEN 'DIAGNOSE_AND_CORRECT'
        WHEN 'CRITICAL'     THEN 'URGENT_INTERVENTION_REQUIRED'
        ELSE                     'ASSESS_TRAJECTORY'
    END AS recommended_action

FROM with_family;

COMMENT ON VIEW ma.v_p7j_recommendation_engine IS
'Sprint 12 -- P7J Moteur de recommandations souveraines -- vision trajectoire
Classification 5 classes basee sur isa_trend_slope (absolu, coherent bornes v1_2026).
3 couches d''acces : Open data / Affilie / Premium.
Modele economique : autofinancement via affiliations institutionnelles.
Independance OSA garantie par les revenus propres.';

-- ── 3. Vue dashboard P7J ─────────────────────────────────────
CREATE OR REPLACE VIEW ma.v_p7j_recommendation_dashboard AS
SELECT
    e.country_iso3,
    e.year,
    e.pillar_code,
    e.trajectory_class,
    e.trajectory_label,
    e.trajectory_signal,
    e.intervention_family_label,
    e.recommended_action,
    e.intervention_priority_class,
    e.isa_observed_score,
    e.trend_slope,
    e.intervention_priority_score,
    e.open_data_allowed,
    e.premium_allowed,
    e.predictive_required,
    ew.country_sovereign_alert_level,
    ew.country_early_warning_score
FROM ma.v_p7j_recommendation_engine e
LEFT JOIN ma.v_isa_early_warning_country_year ew
    ON  ew.country_iso3 = e.country_iso3
    AND ew.year         = e.year;

COMMENT ON VIEW ma.v_p7j_recommendation_dashboard IS
'Sprint 12 -- Dashboard P7J -- vue synthetique pour interface publique et API.';

-- ── 4. Vue publique open data ─────────────────────────────────
CREATE OR REPLACE VIEW mg.v_public_p7j_recommendations AS
SELECT
    d.country_iso3,
    d.year,
    d.pillar_code,
    d.trajectory_class,
    d.trajectory_label,
    d.trajectory_signal,
    d.intervention_family_label,
    d.intervention_priority_class,
    d.country_sovereign_alert_level
FROM ma.v_p7j_recommendation_dashboard d
WHERE d.open_data_allowed = TRUE
  AND d.year >= 2020;

COMMENT ON VIEW mg.v_public_p7j_recommendations IS
'Sprint 12 -- Couche 0 open data P7J -- classe trajectoire uniquement.
Acces libre. Appel a affiliation pour les couches 1 et 2.';

COMMIT;
