-- =============================================================================
-- OSA / ISA — PATCH P7Z PHASE 2 ENGINE
-- Version : P7Z_V2
-- Schémas : MA (calculs) + RF (paramètres) + MG (gouvernance)
--
-- Contenu :
--   ma.mv_isa_p7z_execution_probability  : probabilité d'exécution par intervention
--   ma.v_isa_p7z_convergence_engine      : modélisation de la convergence vers EXEC_READY
--   ma.v_isa_p7z_cascade_propagation     : propagation systémique des défaillances
--   ma.v_isa_p7z_fragility_engine        : fragilité souveraine agrégée par pays/année
--   mg.v_p7z_phase2_readiness            : état de maturité du moteur Phase 2
--
-- Principe :
--   Phase 2 raffine estimated_execution_probability (Phase 1) avec :
--   - pondération multi-facteurs (gap, uncertainty, maturity, pressure, scenario)
--   - convergence temporelle basée sur gap_decay_rate
--   - propagation cascade entre piliers via cascade_failure_probability
--   - fragilité souveraine agrégée par pays
-- =============================================================================
-- PRÉREQUIS :
--   P7Z Phase 1 installée (rf.isa_p7z_baseline_registry,
--   rf.isa_p7z_probability_model, mg.isa_p7z_governance_policy)
--   P7K V3 FROZEN (ma.mv_isa_executive_master_board)
--   P7H (ma.v_isa_scenario_simulation_engine)
--   P7J (ma.v_isa_decision_priority_engine)
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS mg;

-- =============================================================================
-- 1. ma.mv_isa_p7z_execution_probability
--    Probabilité d'exécution raffinée par intervention
--    Remplace estimated_execution_probability de Phase 1
--    Intègre : gap, uncertainty, maturity, pressure, scenario signals
-- =============================================================================
DROP MATERIALIZED VIEW IF EXISTS ma.mv_isa_p7z_execution_probability CASCADE;

CREATE MATERIALIZED VIEW ma.mv_isa_p7z_execution_probability AS

WITH base AS (
    -- Lecture directe depuis rf.isa_p7z_baseline_registry
    -- mg.v_p7z_simulation_eligibility n'expose pas sovereign_execution_pressure
    SELECT
        b.country_iso3,
        b.year,
        b.pillar_code,
        b.intervention_family_code,
        b.executive_priority_score,
        b.execution_maturity_score,
        b.sovereign_execution_pressure,
        b.calibration_uncertainty_score,
        b.predictive_gap_score,
        b.predictive_execution_status,
        b.executive_master_status,
        CASE
            WHEN b.predictive_gap_score         <= 0.15
             AND b.calibration_uncertainty_score <= 0.30
             AND b.execution_maturity_score      >= 0.55
                THEN 'P7Z_SIMULATION_READY'
            WHEN b.predictive_gap_score         <= 0.35
             AND b.calibration_uncertainty_score <= 0.50
             AND b.execution_maturity_score      >= 0.40
                THEN 'P7Z_SIMULATION_PARTIAL'
            ELSE 'P7Z_MONITORING_ONLY'
        END::TEXT                                       AS p7z_eligibility_class,
        COALESCE(gp.eligible_convergence_modelling, FALSE) AS eligible_convergence_modelling,
        COALESCE(gp.eligible_cascade_modelling,     FALSE) AS eligible_cascade_modelling,
        COALESCE(gp.eligible_fragility_scoring,     FALSE) AS eligible_fragility_scoring,
        COALESCE(gp.eligible_isa_projection,        FALSE) AS eligible_isa_projection,
        pm.gap_decay_rate,
        pm.convergence_horizon_years,
        pm.execution_probability_base,
        pm.uncertainty_penalty,
        pm.systemic_fragility_weight,
        pm.cascade_failure_probability
    FROM rf.isa_p7z_baseline_registry b
    JOIN rf.isa_p7z_probability_model pm
        ON pm.pillar_code = b.pillar_code
    LEFT JOIN mg.isa_p7z_governance_policy gp
        ON gp.eligibility_class = CASE
            WHEN b.predictive_gap_score         <= 0.15
             AND b.calibration_uncertainty_score <= 0.30
             AND b.execution_maturity_score      >= 0.55
                THEN 'P7Z_SIMULATION_READY'
            WHEN b.predictive_gap_score         <= 0.35
             AND b.calibration_uncertainty_score <= 0.50
             AND b.execution_maturity_score      >= 0.40
                THEN 'P7Z_SIMULATION_PARTIAL'
            ELSE 'P7Z_MONITORING_ONLY'
        END
),

-- Signaux scénarios P7H (central + stress)
scenario AS (
    SELECT
        s.country_iso3,
        s.year,
        s.pillar_code,
        MAX(CASE WHEN s.scenario_code = 'CENTRAL'
            THEN s.simulated_isa_delta END)::NUMERIC  AS central_isa_delta,
        MAX(CASE WHEN s.scenario_code = 'STRESS'
            THEN s.simulated_isa_delta END)::NUMERIC  AS stress_isa_delta,
        MAX(CASE WHEN s.scenario_code = 'AMBITIOUS'
            THEN s.simulated_isa_delta END)::NUMERIC  AS ambitious_isa_delta,
        MAX(CASE WHEN s.scenario_code = 'CENTRAL'
            THEN s.simulation_confidence END)::NUMERIC AS central_confidence,
        MAX(CASE WHEN s.scenario_code = 'CENTRAL'
            THEN s.simulation_decision END)::TEXT      AS central_decision
    FROM ma.v_isa_scenario_simulation_engine s
    WHERE s.scenario_code IN ('CENTRAL','STRESS','AMBITIOUS')
    GROUP BY s.country_iso3, s.year, s.pillar_code
),

-- Signaux décision P7J
decision AS (
    SELECT
        d.country_iso3,
        d.year,
        d.pillar_code,
        d.intervention_family_code,
        d.decision_priority_score,
        d.decision_confidence_score,
        d.decision_priority_class,
        d.decision_support_status
    FROM ma.v_isa_decision_priority_engine d
),

combined AS (
    SELECT
        b.*,
        -- Scénarios (NULL si absent)
        COALESCE(s.central_isa_delta,   0)::NUMERIC AS central_isa_delta,
        COALESCE(s.stress_isa_delta,    0)::NUMERIC AS stress_isa_delta,
        COALESCE(s.ambitious_isa_delta, 0)::NUMERIC AS ambitious_isa_delta,
        COALESCE(s.central_confidence,  0)::NUMERIC AS central_confidence,
        COALESCE(s.central_decision, 'UNKNOWN')::TEXT AS central_decision,
        -- Décisions P7J
        COALESCE(d.decision_priority_score,   0)::NUMERIC AS decision_priority_score,
        COALESCE(d.decision_confidence_score, 0)::NUMERIC AS decision_confidence_score,
        COALESCE(d.decision_priority_class, 'DECISION_MONITOR')::TEXT AS decision_priority_class,
        COALESCE(d.decision_support_status, 'UNKNOWN')::TEXT AS decision_support_status
    FROM base b
    LEFT JOIN scenario s
        ON  s.country_iso3 = b.country_iso3
        AND s.year         = b.year
        AND s.pillar_code  = b.pillar_code
    LEFT JOIN decision d
        ON  d.country_iso3             = b.country_iso3
        AND d.year                     = b.year
        AND d.pillar_code              = b.pillar_code
        AND d.intervention_family_code = b.intervention_family_code
),

scored AS (
    SELECT
        *,

        -- =================================================================
        -- COMPOSANTE 1 : probabilité de base corrigée par gap et uncertainty
        -- =================================================================
        ROUND(GREATEST(0.0, LEAST(1.0,
            execution_probability_base
            - (predictive_gap_score       * 0.40)
            - (calibration_uncertainty_score * uncertainty_penalty)
            + (execution_maturity_score   * 0.15)
        ))::NUMERIC, 4)                                 AS prob_base_corrected,

        -- =================================================================
        -- COMPOSANTE 2 : signal scénario
        -- central_isa_delta positif → probabilité en hausse
        -- stress_isa_delta négatif → probabilité en baisse
        -- =================================================================
        ROUND(GREATEST(-0.20, LEAST(0.20,
            COALESCE(central_isa_delta, 0) * 0.50
            + COALESCE(stress_isa_delta, 0) * 0.25
            + COALESCE(central_confidence, 0) * 0.05
        ))::NUMERIC, 4)                                 AS prob_scenario_signal,

        -- =================================================================
        -- COMPOSANTE 3 : signal décision P7J
        -- DECISION_CRITICAL → +0.08, DECISION_HIGH → +0.04
        -- =================================================================
        ROUND(CASE decision_priority_class
            WHEN 'DECISION_CRITICAL' THEN  0.08
            WHEN 'DECISION_HIGH'     THEN  0.04
            WHEN 'DECISION_STANDARD' THEN  0.01
            ELSE                          -0.02
        END::NUMERIC, 4)                                AS prob_decision_signal,

        -- =================================================================
        -- COMPOSANTE 4 : pénalité de pression souveraine
        -- pression élevée → exécution plus difficile
        -- =================================================================
        ROUND(GREATEST(-0.10, LEAST(0.0,
            (sovereign_execution_pressure - 0.60) * (-0.15)
        ))::NUMERIC, 4)                                 AS prob_pressure_penalty,

        -- =================================================================
        -- Convergence temporelle : années restantes pour atteindre EXEC_READY
        -- convergence_years = predictive_gap / gap_decay_rate
        -- =================================================================
        ROUND(CASE
            WHEN gap_decay_rate > 0
            THEN LEAST(50.0, predictive_gap_score / gap_decay_rate)
            ELSE 50.0
        END::NUMERIC, 1)                                AS estimated_convergence_years

    FROM combined
),

final_prob AS (
    SELECT
        *,
        -- Probabilité d'exécution finale : somme des composantes
        ROUND(GREATEST(0.0, LEAST(1.0,
            prob_base_corrected
            + prob_scenario_signal
            + prob_decision_signal
            + prob_pressure_penalty
        ))::NUMERIC, 3)                                 AS execution_probability,

        -- Intervalle de confiance basé sur l'uncertainty
        -- half_width = uncertainty * 0.25 (±12.5% max pour uncertainty=0.50)
        ROUND((calibration_uncertainty_score * 0.25)
            ::NUMERIC, 3)                               AS probability_confidence_interval,

        -- Classe de probabilité
        CASE
            WHEN GREATEST(0.0, LEAST(1.0,
                prob_base_corrected + prob_scenario_signal
                + prob_decision_signal + prob_pressure_penalty
            )) >= 0.60 THEN 'HIGH_PROBABILITY'
            WHEN GREATEST(0.0, LEAST(1.0,
                prob_base_corrected + prob_scenario_signal
                + prob_decision_signal + prob_pressure_penalty
            )) >= 0.40 THEN 'MEDIUM_PROBABILITY'
            WHEN GREATEST(0.0, LEAST(1.0,
                prob_base_corrected + prob_scenario_signal
                + prob_decision_signal + prob_pressure_penalty
            )) >= 0.20 THEN 'LOW_PROBABILITY'
            ELSE             'VERY_LOW_PROBABILITY'
        END::TEXT                                       AS execution_probability_class
    FROM scored
)

SELECT
    -- Identifiants
    country_iso3, year, pillar_code, intervention_family_code,

    -- Scores P7K source
    ROUND(executive_priority_score,        3) AS executive_priority_score,
    ROUND(execution_maturity_score,        3) AS execution_maturity_score,
    ROUND(sovereign_execution_pressure,    3) AS sovereign_execution_pressure,
    ROUND(calibration_uncertainty_score,   3) AS calibration_uncertainty_score,
    ROUND(predictive_gap_score,            3) AS predictive_gap_score,
    predictive_execution_status,
    executive_master_status,

    -- Éligibilité P7Z
    p7z_eligibility_class,
    eligible_convergence_modelling,
    eligible_cascade_modelling,
    eligible_fragility_scoring,
    eligible_isa_projection,

    -- Probability model
    ROUND(gap_decay_rate,                  3) AS gap_decay_rate,
    ROUND(convergence_horizon_years,       1) AS convergence_horizon_years,
    ROUND(systemic_fragility_weight,       3) AS systemic_fragility_weight,
    ROUND(cascade_failure_probability,     3) AS cascade_failure_probability,

    -- Signaux
    ROUND(central_isa_delta,               3) AS central_isa_delta,
    ROUND(stress_isa_delta,                3) AS stress_isa_delta,
    ROUND(ambitious_isa_delta,             3) AS ambitious_isa_delta,
    ROUND(central_confidence,              3) AS central_confidence,
    central_decision,
    ROUND(decision_priority_score,         3) AS decision_priority_score,
    decision_priority_class,
    decision_support_status,

    -- Composantes de probabilité
    ROUND(prob_base_corrected,             3) AS prob_base_corrected,
    ROUND(prob_scenario_signal,            3) AS prob_scenario_signal,
    ROUND(prob_decision_signal,            3) AS prob_decision_signal,
    ROUND(prob_pressure_penalty,           3) AS prob_pressure_penalty,

    -- Résultat probabiliste final
    execution_probability,
    probability_confidence_interval,
    execution_probability_class,
    estimated_convergence_years

FROM final_prob
WITH DATA;

-- Index
CREATE INDEX idx_p7z_prob_country_year
    ON ma.mv_isa_p7z_execution_probability (country_iso3, year);
CREATE INDEX idx_p7z_prob_pillar
    ON ma.mv_isa_p7z_execution_probability (pillar_code);
CREATE INDEX idx_p7z_prob_class
    ON ma.mv_isa_p7z_execution_probability (execution_probability_class);
CREATE INDEX idx_p7z_prob_eligibility
    ON ma.mv_isa_p7z_execution_probability (p7z_eligibility_class);
CREATE INDEX idx_p7z_prob_score
    ON ma.mv_isa_p7z_execution_probability (execution_probability DESC);
CREATE INDEX idx_p7z_prob_convergence
    ON ma.mv_isa_p7z_execution_probability (estimated_convergence_years);

ANALYZE ma.mv_isa_p7z_execution_probability;

-- =============================================================================
-- 2. ma.v_isa_p7z_convergence_engine
--    Modélisation de la convergence vers EXEC_READY_CAUTION
--    Par pays/pilier — horizon temporel et vitesse de convergence
-- =============================================================================
DROP VIEW IF EXISTS ma.v_isa_p7z_convergence_engine;

CREATE VIEW ma.v_isa_p7z_convergence_engine AS
WITH convergence AS (
    SELECT
        p.country_iso3,
        p.year,
        p.pillar_code,
        -- Meilleure intervention par pilier (min gap)
        MIN(p.predictive_gap_score)                     AS min_gap,
        MAX(p.execution_probability)                    AS max_exec_probability,
        AVG(p.execution_probability)                    AS avg_exec_probability,
        MIN(p.estimated_convergence_years)              AS min_convergence_years,
        AVG(p.estimated_convergence_years)              AS avg_convergence_years,
        AVG(p.gap_decay_rate)                           AS avg_gap_decay_rate,
        COUNT(*)                                        AS nb_interventions,
        COUNT(*) FILTER (
            WHERE p.p7z_eligibility_class = 'P7Z_SIMULATION_READY'
        )                                               AS nb_ready,
        COUNT(*) FILTER (
            WHERE p.p7z_eligibility_class = 'P7Z_SIMULATION_PARTIAL'
        )                                               AS nb_partial,
        -- Signal scénario agrégé
        AVG(p.central_isa_delta)                        AS avg_central_isa_delta,
        AVG(p.stress_isa_delta)                         AS avg_stress_isa_delta
    FROM ma.mv_isa_p7z_execution_probability p
    WHERE p.eligible_convergence_modelling = TRUE
    GROUP BY p.country_iso3, p.year, p.pillar_code
)
SELECT
    c.*,
    -- Classe de convergence
    CASE
        WHEN c.min_convergence_years <= 2.0  THEN 'CONVERGENCE_IMMINENT'
        WHEN c.min_convergence_years <= 5.0  THEN 'CONVERGENCE_SHORT_TERM'
        WHEN c.min_convergence_years <= 10.0 THEN 'CONVERGENCE_MEDIUM_TERM'
        ELSE                                      'CONVERGENCE_LONG_TERM'
    END::TEXT                                           AS convergence_class,
    -- Tendance scénario
    CASE
        WHEN c.avg_central_isa_delta > 0.02  THEN 'IMPROVING'
        WHEN c.avg_central_isa_delta < -0.02 THEN 'DETERIORATING'
        ELSE                                      'STABLE'
    END::TEXT                                           AS scenario_trend,
    ROUND(c.min_gap,               3)                   AS min_gap_r,
    ROUND(c.max_exec_probability,  3)                   AS max_exec_prob_r,
    ROUND(c.avg_exec_probability,  3)                   AS avg_exec_prob_r,
    ROUND(c.min_convergence_years, 1)                   AS min_conv_years_r,
    ROUND(c.avg_convergence_years, 1)                   AS avg_conv_years_r,
    ROUND(c.avg_gap_decay_rate,    3)                   AS avg_decay_rate_r,
    ROUND(c.avg_central_isa_delta, 3)                   AS avg_central_delta_r,
    ROUND(c.avg_stress_isa_delta,  3)                   AS avg_stress_delta_r
FROM convergence c;

COMMENT ON VIEW ma.v_isa_p7z_convergence_engine IS
    'Modélisation de la convergence vers EXEC_READY_CAUTION par pays/pilier/année.
     Filtre sur eligible_convergence_modelling=TRUE.
     convergence_class : IMMINENT (<2 ans) / SHORT_TERM (<5) / MEDIUM_TERM (<10) / LONG_TERM.
     scenario_trend : IMPROVING / STABLE / DETERIORATING selon central_isa_delta.';

-- =============================================================================
-- 3. ma.v_isa_p7z_cascade_propagation
--    Propagation systémique des défaillances entre piliers
--    Un pilier défaillant (low probability) impacte les autres
-- =============================================================================
DROP VIEW IF EXISTS ma.v_isa_p7z_cascade_propagation;

CREATE VIEW ma.v_isa_p7z_cascade_propagation AS
WITH pillar_scores AS (
    -- Score d'exécution moyen par pays/année/pilier
    SELECT
        p.country_iso3,
        p.year,
        p.pillar_code,
        AVG(p.execution_probability)                    AS avg_exec_prob,
        MIN(p.execution_probability)                    AS min_exec_prob,
        AVG(p.cascade_failure_probability)              AS cascade_prob,
        AVG(p.systemic_fragility_weight)                AS fragility_weight,
        COUNT(*) FILTER (
            WHERE p.p7z_eligibility_class = 'P7Z_SIMULATION_READY'
        )                                               AS nb_ready
    FROM ma.mv_isa_p7z_execution_probability p
    WHERE p.eligible_cascade_modelling = TRUE
    GROUP BY p.country_iso3, p.year, p.pillar_code
),
cascade_impact AS (
    SELECT
        ps.*,
        -- Probabilité de défaillance = 1 - avg_exec_prob
        ROUND((1.0 - ps.avg_exec_prob)::NUMERIC, 3)     AS failure_probability,
        -- Impact cascade = failure_prob * cascade_prob * fragility_weight
        -- Représente la probabilité qu'une défaillance dans ce pilier
        -- se propage au système souverain
        ROUND((
            (1.0 - ps.avg_exec_prob)
            * ps.cascade_prob
            * ps.fragility_weight
        )::NUMERIC, 3)                                  AS cascade_impact_score,
        -- Score de résilience = inverse de l'impact cascade
        ROUND((1.0 - (
            (1.0 - ps.avg_exec_prob)
            * ps.cascade_prob
            * ps.fragility_weight
        ))::NUMERIC, 3)                                 AS pillar_resilience_score
    FROM pillar_scores ps
)
SELECT
    ci.*,
    -- Classe de risque cascade
    CASE
        WHEN ci.cascade_impact_score >= 0.15 THEN 'CASCADE_CRITICAL'
        WHEN ci.cascade_impact_score >= 0.08 THEN 'CASCADE_HIGH'
        WHEN ci.cascade_impact_score >= 0.04 THEN 'CASCADE_MODERATE'
        ELSE                                      'CASCADE_LOW'
    END::TEXT                                           AS cascade_risk_class,
    ROUND(ci.avg_exec_prob,    3)                       AS avg_exec_prob_r,
    ROUND(ci.min_exec_prob,    3)                       AS min_exec_prob_r,
    ROUND(ci.cascade_prob,     3)                       AS cascade_prob_r,
    ROUND(ci.fragility_weight, 3)                       AS fragility_weight_r
FROM cascade_impact ci;

COMMENT ON VIEW ma.v_isa_p7z_cascade_propagation IS
    'Propagation systémique des défaillances entre piliers par pays/année.
     Filtre sur eligible_cascade_modelling=TRUE (P7Z_SIMULATION_READY uniquement).
     cascade_impact_score : probabilité de propagation au système souverain.
     CASCADE_CRITICAL >= 0.15 : intervention immédiate requise.
     pillar_resilience_score : capacité du pilier à absorber les chocs.';

-- =============================================================================
-- 4. ma.v_isa_p7z_fragility_engine
--    Fragilité souveraine agrégée par pays/année
--    Synthèse de tous les piliers en un indice de fragilité national
-- =============================================================================
DROP VIEW IF EXISTS ma.v_isa_p7z_fragility_engine;

CREATE VIEW ma.v_isa_p7z_fragility_engine AS
WITH country_fragility AS (
    SELECT
        cp.country_iso3,
        cp.year,
        -- Fragilité = moyenne pondérée des cascade_impact_scores
        -- pondérée par fragility_weight de chaque pilier
        ROUND(SUM(
            cp.cascade_impact_score * cp.fragility_weight
        ) / NULLIF(SUM(cp.fragility_weight), 0)
        ::NUMERIC, 3)                                   AS sovereign_fragility_index,
        -- Résilience = inverse de la fragilité pondérée
        ROUND(SUM(
            cp.pillar_resilience_score * cp.fragility_weight
        ) / NULLIF(SUM(cp.fragility_weight), 0)
        ::NUMERIC, 3)                                   AS sovereign_resilience_index,
        -- Probabilité d'exécution nationale moyenne
        ROUND(AVG(cp.avg_exec_prob_r),   3)             AS avg_national_exec_probability,
        -- Pilier le plus fragile
        (ARRAY_AGG(cp.pillar_code
            ORDER BY cp.cascade_impact_score DESC
        ))[1]                                           AS most_fragile_pillar,
        -- Pilier le plus résilient
        (ARRAY_AGG(cp.pillar_code
            ORDER BY cp.pillar_resilience_score DESC
        ))[1]                                           AS most_resilient_pillar,
        -- Nombre de piliers en CASCADE_CRITICAL ou HIGH
        COUNT(*) FILTER (
            WHERE cp.cascade_risk_class IN ('CASCADE_CRITICAL','CASCADE_HIGH')
        )                                               AS nb_high_cascade_pillars,
        -- Nombre de piliers READY
        SUM(cp.nb_ready)                                AS total_ready_interventions,
        COUNT(DISTINCT cp.pillar_code)                  AS nb_pillars_assessed
    FROM ma.v_isa_p7z_cascade_propagation cp
    GROUP BY cp.country_iso3, cp.year
)
SELECT
    cf.*,
    -- Classe de fragilité souveraine
    CASE
        WHEN cf.sovereign_fragility_index >= 0.12 THEN 'SOVEREIGN_FRAGILE'
        WHEN cf.sovereign_fragility_index >= 0.07 THEN 'SOVEREIGN_VULNERABLE'
        WHEN cf.sovereign_fragility_index >= 0.03 THEN 'SOVEREIGN_MODERATE'
        ELSE                                           'SOVEREIGN_RESILIENT'
    END::TEXT                                           AS sovereign_fragility_class,
    -- Statut P7Z national
    CASE
        WHEN cf.nb_high_cascade_pillars >= 5
            THEN 'P7Z_NATIONAL_CRITICAL'
        WHEN cf.nb_high_cascade_pillars >= 3
            THEN 'P7Z_NATIONAL_HIGH_RISK'
        WHEN cf.nb_high_cascade_pillars >= 1
            THEN 'P7Z_NATIONAL_MODERATE_RISK'
        ELSE
            'P7Z_NATIONAL_STABLE'
    END::TEXT                                           AS p7z_national_status
FROM country_fragility cf;

COMMENT ON VIEW ma.v_isa_p7z_fragility_engine IS
    'Fragilité souveraine agrégée par pays/année.
     sovereign_fragility_index : indice [0-1] de fragilité nationale.
     sovereign_resilience_index : capacité d''absorption nationale.
     most_fragile_pillar : pilier contribuant le plus à la fragilité.
     SOVEREIGN_FRAGILE >= 0.12 : pays nécessitant intervention systémique urgente.
     p7z_national_status : statut global P7Z du pays.';

-- =============================================================================
-- 5. mg.v_p7z_phase2_readiness
--    État de maturité du moteur P7Z Phase 2
--    Monitoring de la couverture et de la qualité des calculs
-- =============================================================================
DROP VIEW IF EXISTS mg.v_p7z_phase2_readiness;

CREATE VIEW mg.v_p7z_phase2_readiness AS
SELECT
    -- MV principale
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability)
                                                        AS mv_rows,
    (SELECT COUNT(DISTINCT country_iso3)
     FROM ma.mv_isa_p7z_execution_probability)          AS nb_countries,
    (SELECT COUNT(DISTINCT pillar_code)
     FROM ma.mv_isa_p7z_execution_probability)          AS nb_pillars,

    -- Distribution probabilité
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
     WHERE execution_probability_class = 'HIGH_PROBABILITY')
                                                        AS nb_high_prob,
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
     WHERE execution_probability_class = 'MEDIUM_PROBABILITY')
                                                        AS nb_medium_prob,
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
     WHERE execution_probability_class = 'LOW_PROBABILITY')
                                                        AS nb_low_prob,
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
     WHERE execution_probability_class = 'VERY_LOW_PROBABILITY')
                                                        AS nb_very_low_prob,

    -- Convergence
    (SELECT COUNT(*) FROM ma.v_isa_p7z_convergence_engine
     WHERE convergence_class = 'CONVERGENCE_IMMINENT')  AS nb_imminent_convergence,
    (SELECT COUNT(*) FROM ma.v_isa_p7z_convergence_engine
     WHERE convergence_class = 'CONVERGENCE_SHORT_TERM') AS nb_short_term_convergence,

    -- Cascade
    (SELECT COUNT(*) FROM ma.v_isa_p7z_cascade_propagation
     WHERE cascade_risk_class = 'CASCADE_CRITICAL')     AS nb_cascade_critical,
    (SELECT COUNT(*) FROM ma.v_isa_p7z_cascade_propagation
     WHERE cascade_risk_class = 'CASCADE_HIGH')         AS nb_cascade_high,

    -- Fragilité nationale
    (SELECT COUNT(*) FROM ma.v_isa_p7z_fragility_engine
     WHERE sovereign_fragility_class = 'SOVEREIGN_FRAGILE')
                                                        AS nb_fragile_countries,
    (SELECT COUNT(*) FROM ma.v_isa_p7z_fragility_engine
     WHERE p7z_national_status = 'P7Z_NATIONAL_CRITICAL')
                                                        AS nb_national_critical,

    -- Qualité
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
     WHERE execution_probability IS NULL)               AS null_probabilities,
    (SELECT ROUND(AVG(execution_probability),3)
     FROM ma.mv_isa_p7z_execution_probability)          AS avg_execution_probability,
    (SELECT ROUND(AVG(probability_confidence_interval),3)
     FROM ma.mv_isa_p7z_execution_probability)          AS avg_confidence_interval,

    -- Statut global
    CASE
        WHEN (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
              WHERE execution_probability IS NULL) = 0
        AND  (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability) > 0
        THEN 'P7Z_PHASE2_READY'
        ELSE 'P7Z_PHASE2_INCOMPLETE'
    END::TEXT                                           AS p7z_phase2_status;

COMMENT ON VIEW mg.v_p7z_phase2_readiness IS
    'État de maturité du moteur P7Z Phase 2.
     Monitoring de la couverture et de la qualité des calculs probabilistes.
     p7z_phase2_status = P7Z_PHASE2_READY : moteur opérationnel pour P8.';

-- =============================================================================
-- 6. Mise à jour package_lifecycle P7Z → V2
-- =============================================================================
UPDATE rf.package_lifecycle
SET
    package_label   = 'P7Z Predictive Sovereign Intelligence — Phase 2 Engine',
    package_status  = 'ACTIVE',
    notes           = 'P7Z Phase 2 : mv_isa_p7z_execution_probability (probabilité multi-facteurs), '
                   || 'v_isa_p7z_convergence_engine (convergence temporelle), '
                   || 'v_isa_p7z_cascade_propagation (propagation systémique), '
                   || 'v_isa_p7z_fragility_engine (fragilité souveraine nationale). '
                   || 'Consomme P7K V3 FROZEN + P7H + P7J. Prépare P8 V2.',
    updated_at      = NOW()
WHERE package_code = 'P7Z';

-- =============================================================================
-- 7. Ajouter P7Z Phase 2 au lineage MG
-- =============================================================================
INSERT INTO mg.isa_view_lineage_registry (
    source_schema, source_object, source_object_type,
    target_schema, target_object, target_object_type,
    dependency_type, cascade_risk, refresh_order,
    package_code, lineage_note
) VALUES
('ma', 'mv_isa_p7z_execution_probability', 'MATERIALIZED_VIEW',
 'mg', 'v_p7z_simulation_eligibility',     'VIEW',
 'DIRECT_READ', 'HIGH', 60, 'P7Z',
 'MV P7Z Phase 2 lit la vue éligibilité Phase 1'),

('ma', 'mv_isa_p7z_execution_probability', 'MATERIALIZED_VIEW',
 'rf', 'isa_p7z_probability_model',        'TABLE',
 'JOIN', 'HIGH', 60, 'P7Z',
 'MV P7Z Phase 2 joint le probability model RF'),

('ma', 'mv_isa_p7z_execution_probability', 'MATERIALIZED_VIEW',
 'ma', 'v_isa_scenario_simulation_engine', 'VIEW',
 'JOIN', 'MEDIUM', 60, 'P7Z',
 'MV P7Z Phase 2 joint les scénarios P7H'),

('ma', 'mv_isa_p7z_execution_probability', 'MATERIALIZED_VIEW',
 'ma', 'v_isa_decision_priority_engine',   'VIEW',
 'JOIN', 'MEDIUM', 60, 'P7Z',
 'MV P7Z Phase 2 joint les décisions P7J'),

('ma', 'v_isa_p7z_convergence_engine',     'VIEW',
 'ma', 'mv_isa_p7z_execution_probability', 'MATERIALIZED_VIEW',
 'DIRECT_READ', 'HIGH', 70, 'P7Z',
 'Convergence engine lit la MV Phase 2 — CASCADE si DROP MV'),

('ma', 'v_isa_p7z_cascade_propagation',    'VIEW',
 'ma', 'mv_isa_p7z_execution_probability', 'MATERIALIZED_VIEW',
 'DIRECT_READ', 'HIGH', 70, 'P7Z',
 'Cascade propagation lit la MV Phase 2 — CASCADE si DROP MV'),

('ma', 'v_isa_p7z_fragility_engine',       'VIEW',
 'ma', 'v_isa_p7z_cascade_propagation',    'VIEW',
 'DIRECT_READ', 'HIGH', 80, 'P7Z',
 'Fragility engine lit cascade propagation — CASCADE si DROP cascade view'),

('mg', 'v_p7z_phase2_readiness',           'VIEW',
 'ma', 'mv_isa_p7z_execution_probability', 'MATERIALIZED_VIEW',
 'DIRECT_READ', 'MEDIUM', 70, 'P7Z',
 'Readiness view MG lit la MV Phase 2 pour monitoring');

-- =============================================================================
-- 8. Validation finale
-- =============================================================================
DO $$
DECLARE
    v_mv_rows       INTEGER;
    v_null_prob     INTEGER;
    v_convergence   INTEGER;
    v_cascade       INTEGER;
    v_fragility     INTEGER;
    v_high_prob     INTEGER;
    v_fragile       INTEGER;
    v_phase2_status TEXT;
BEGIN
    SELECT COUNT(*) INTO v_mv_rows
        FROM ma.mv_isa_p7z_execution_probability;
    SELECT COUNT(*) INTO v_null_prob
        FROM ma.mv_isa_p7z_execution_probability
        WHERE execution_probability IS NULL;
    SELECT COUNT(*) INTO v_convergence
        FROM ma.v_isa_p7z_convergence_engine;
    SELECT COUNT(*) INTO v_cascade
        FROM ma.v_isa_p7z_cascade_propagation;
    SELECT COUNT(*) INTO v_fragility
        FROM ma.v_isa_p7z_fragility_engine;
    SELECT COUNT(*) INTO v_high_prob
        FROM ma.mv_isa_p7z_execution_probability
        WHERE execution_probability_class = 'HIGH_PROBABILITY';
    SELECT COUNT(*) INTO v_fragile
        FROM ma.v_isa_p7z_fragility_engine
        WHERE sovereign_fragility_class = 'SOVEREIGN_FRAGILE';
    SELECT p7z_phase2_status INTO v_phase2_status
        FROM mg.v_p7z_phase2_readiness;

    RAISE NOTICE
        'P7Z Phase 2 : mv_rows=%, null_prob=%, convergence_rows=%, '
        'cascade_rows=%, fragility_rows=%, high_prob=%, fragile_countries=%, status=%',
        v_mv_rows, v_null_prob, v_convergence, v_cascade,
        v_fragility, v_high_prob, v_fragile, v_phase2_status;

    IF v_mv_rows = 0 THEN
        RAISE EXCEPTION 'ABORT : mv_isa_p7z_execution_probability vide';
    END IF;
    IF v_null_prob > 0 THEN
        RAISE EXCEPTION 'ABORT : % lignes avec execution_probability NULL', v_null_prob;
    END IF;
    IF v_phase2_status <> 'P7Z_PHASE2_READY' THEN
        RAISE EXCEPTION 'ABORT : P7Z Phase 2 status = %', v_phase2_status;
    END IF;
END $$;

COMMIT;
