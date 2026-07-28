-- ============================================================
-- ma.mv_isa_observed_scores_by_pillar -- copie MATERIALISEE parallele
-- 28 juillet 2026
-- ============================================================
-- Suite du chantier performance : ma.v_isa_observed_scores_by_pillar
-- (source du reste des 1,74s mesures) agrege ma.v_isa_observed_publication_engine
-- (316 670 lignes, 15 ans, 2010-2024) SANS AUCUN FILTRE ANNEE -- elle
-- recalcule l'agregat sur 15 ans d'historique complet a CHAQUE appel,
-- alors que l'immense majorite des consommateurs (notre chaine P7J)
-- n'a besoin que de la derniere annee. Confirme le risque de
-- performance PLURIANNUELLE souleve par Theo : ce cout grossira d'une
-- annee supplementaire a chaque cycle de publication ISA.
--
-- 9 vues en dependent reellement (verifie via pg_depend) :
-- mv_isa_pillar_breakdown (deja materialisee !), v_isa_observed_publication_readiness,
-- v_isa_observed_scores_by_country_year, v_isa_pillar_breakdown,
-- v_p7f_observed_pillar_source, v_p7g_forecast_source,
-- v_p7j_recommendation_engine (la notre), v_p7x_observed_pillar_source.
-- AUCUN DROP direct envisageable -- meme patron prudent que pour
-- ma.v_p7i_risk_source hier : copie MATERIALISEE PARALLELE, la vue
-- originale reste INTACTE pour tous les autres consommateurs.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE MATERIALIZED VIEW ma.mv_isa_observed_scores_by_pillar AS
WITH agg AS (
    SELECT
        v_isa_observed_publication_engine.country_iso3,
        v_isa_observed_publication_engine.region_code,
        v_isa_observed_publication_engine.economic_region_code,
        v_isa_observed_publication_engine.region_label,
        v_isa_observed_publication_engine.economic_region_label,
        v_isa_observed_publication_engine.year,
        v_isa_observed_publication_engine.pillar_code,
        v_isa_observed_publication_engine.publication_status,
        v_isa_observed_publication_engine.publication_cycle,
        v_isa_observed_publication_engine.methodology_version,
        count(*) AS nb_indicators_observed,
        sum(v_isa_observed_publication_engine.valid_observation_flag) AS nb_valid_observations,
        sum(v_isa_observed_publication_engine.estimated_observation_flag) AS nb_estimated_observations,
        round(avg(v_isa_observed_publication_engine.observation_confidence), 3) AS avg_observation_confidence,
        round(sum(v_isa_observed_publication_engine.valid_observation_flag)::numeric / NULLIF(count(*), 0)::numeric, 3) AS data_completeness,
        round(avg(v_isa_observed_publication_engine.observed_isa_component), 3) AS isa_observed_score,
        round(avg(v_isa_observed_publication_engine.observed_sovereignty_component), 3) AS sovereignty_observed_score,
        round(avg(v_isa_observed_publication_engine.observed_vulnerability_component), 3) AS vulnerability_observed_score,
        round(avg(v_isa_observed_publication_engine.observed_resilience_component), 3) AS resilience_observed_score,
        round(avg(v_isa_observed_publication_engine.observed_forecast_component), 3) AS forecast_readiness_score,
        round(avg(v_isa_observed_publication_engine.observed_ml_component), 3) AS ml_readiness_score,
        CASE
            WHEN sum(v_isa_observed_publication_engine.valid_observation_flag) = 0 THEN 'NOT_CERTIFIED'::text
            WHEN avg(v_isa_observed_publication_engine.observation_confidence) >= 0.85 AND sum(v_isa_observed_publication_engine.estimated_observation_flag) = 0 THEN 'CERTIFIED_OBSERVED_HIGH'::text
            WHEN avg(v_isa_observed_publication_engine.observation_confidence) >= 0.65 THEN 'CERTIFIED_OBSERVED_CONTROLLED'::text
            ELSE 'LOW_CONFIDENCE_OBSERVED'::text
        END AS certification_status
    FROM ma.v_isa_observed_publication_engine
    GROUP BY v_isa_observed_publication_engine.country_iso3, v_isa_observed_publication_engine.region_code, v_isa_observed_publication_engine.economic_region_code, v_isa_observed_publication_engine.region_label, v_isa_observed_publication_engine.economic_region_label, v_isa_observed_publication_engine.year, v_isa_observed_publication_engine.pillar_code, v_isa_observed_publication_engine.publication_status, v_isa_observed_publication_engine.publication_cycle, v_isa_observed_publication_engine.methodology_version
)
SELECT country_iso3,
    region_code,
    economic_region_code,
    region_label,
    economic_region_label,
    year,
    pillar_code,
    publication_status,
    publication_cycle,
    methodology_version,
    nb_indicators_observed,
    nb_valid_observations,
    nb_estimated_observations,
    avg_observation_confidence,
    data_completeness,
    isa_observed_score,
    sovereignty_observed_score,
    vulnerability_observed_score,
    resilience_observed_score,
    forecast_readiness_score,
    ml_readiness_score,
    certification_status,
    CASE
        WHEN publication_status = 'OFFICIAL_CONSOLIDATED'::text AND data_completeness >= 0.70 THEN 'PUBLISH_OFFICIAL'::text
        WHEN publication_status = 'PROVISIONAL_N1'::text THEN 'PUBLISH_PROVISIONAL_WITH_WARNING'::text
        WHEN publication_status = 'CURRENT_YEAR_MONITORING'::text THEN 'MONITOR_ONLY'::text
        ELSE 'DO_NOT_PUBLISH'::text
    END AS publication_decision,
    CASE
        WHEN publication_status = 'PROVISIONAL_N1'::text THEN 'Données incomplètes ou en cours de consolidation.'::text
        WHEN publication_status = 'OFFICIAL_CONSOLIDATED'::text THEN 'Score officiel consolidé.'::text
        WHEN publication_status = 'CURRENT_YEAR_MONITORING'::text THEN 'Année courante en monitoring, non publiée officiellement.'::text
        ELSE 'Score hors fenêtre de publication.'::text
    END AS publication_note
FROM agg;

CREATE UNIQUE INDEX idx_mv_isa_scores_pillar_pk ON ma.mv_isa_observed_scores_by_pillar (country_iso3, pillar_code, year);
CREATE INDEX idx_mv_isa_scores_pillar_year ON ma.mv_isa_observed_scores_by_pillar (year);

COMMIT;

-- Verification post-execution
SELECT COUNT(*), COUNT(DISTINCT year) FROM ma.mv_isa_observed_scores_by_pillar;
\d ma.mv_isa_observed_scores_by_pillar
