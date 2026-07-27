-- ============================================================
-- pub.mv_isa_opportunity_catalog -- refonte (convergence P7J/OIM)
-- 27 juillet 2026
-- ============================================================
-- Point B de la convergence P7J/OIM/OSOA. Vue MATERIALISEE --
-- DROP + CREATE (impossible de simplement modifier la requete).
-- Verifie avant execution : aucune vraie dependance externe
-- (pg_depend ne renvoie que la dependance interne de la vue sur
-- elle-meme, artefact normal des vues materialisees). Index
-- existants a l'identique recrees en fin de script :
--   idx_mv_opportunity_pk (UNIQUE, country_iso3, pillar_code)
--   idx_mv_opportunity_country, idx_mv_opportunity_pillar,
--   idx_mv_opportunity_class, idx_mv_opportunity_region
--
-- CHANGEMENTS :
-- 1. LEFT JOIN vers mg.pillar_strategic_vision sur (country_iso3,
--    pillar_code, year) -- les 3 clefs existent des deux cotes
--    (le catalogue P7J n'affiche deja qu'une seule annee -- la plus
--    recente -- par pays+pilier, confirme par l'index UNIQUE existant
--    qui ne porte pas sur l'annee).
-- 2. Deux nouvelles colonnes exposees SEULEMENT si une vision existe :
--    vision_id, vision_status -- PAS de lien direct (page vision
--    inexistante a ce jour, doctrine de ne jamais exposer un lien
--    mort, cf. sessions precedentes).
-- 3. feasibility_call ne mentionne plus le code interne "P7J" --
--    remplace par "Moteur de genie scientifique" (nom officiel
--    ADR-010, deja utilise dans OSOA_DISCLAIMER corrige la veille).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

DROP MATERIALIZED VIEW pub.mv_isa_opportunity_catalog;

CREATE MATERIALIZED VIEW pub.mv_isa_opportunity_catalog AS
SELECT
    r.country_iso3,
    r.year,
    r.pillar_code,
    r.intervention_family_code,
    r.intervention_family_label,
    r.strategic_objective,
    r.consultation_theme,
    CASE
        WHEN r.trajectory_class = 'CRITICAL' AND r.intervention_priority_class = 'PRIORITY_CRITICAL' THEN 'HIGH_IMPACT_OPPORTUNITY'
        WHEN r.trajectory_class = ANY (ARRAY['CRITICAL', 'DECLINING']) AND r.intervention_priority_class = ANY (ARRAY['PRIORITY_CRITICAL', 'PRIORITY_HIGH']) THEN 'SIGNIFICANT_OPPORTUNITY'
        WHEN r.trajectory_class = 'STABLE' AND r.intervention_priority_class = 'PRIORITY_HIGH' THEN 'UNLOCK_OPPORTUNITY'
        ELSE 'MONITORING_OPPORTUNITY'
    END AS opportunity_class,
    CASE
        WHEN r.trajectory_class = 'CRITICAL' THEN 'Strong positive delta achievable -- see feasibility study'
        WHEN r.trajectory_class = 'DECLINING' THEN 'Moderate positive delta achievable -- see feasibility study'
        WHEN r.trajectory_class = 'STABLE' THEN 'Unlock potential identified -- see feasibility study'
        ELSE 'Consolidation delta achievable'
    END AS delta_potential_label,
    r.trajectory_class,
    r.intervention_priority_class,
    round(r.intervention_priority_score, 4) AS intervention_priority_score,
    ca.region_code,
    rg.name_fr AS region_label,
    v.id AS vision_id,
    v.status AS vision_status,
    'This opportunity has been identified by OSA''s Scientific Engineering Engine (OIM/OSOA). Contact OSA for a full feasibility study.' AS feasibility_call,
    'OSA Observatory -- CC-BY-NC-4.0' AS source
FROM ma.v_p7j_recommendation_engine r
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = r.country_iso3
LEFT JOIN rf.regions rg ON rg.code::text = ca.region_code::text
LEFT JOIN mg.pillar_strategic_vision v
    ON v.country_iso3 = r.country_iso3
    AND v.pillar_code = r.pillar_code
    AND v.year = r.year
WHERE r.year = (SELECT max(year) FROM ma.v_p7j_recommendation_engine)
    AND r.trajectory_class = ANY (ARRAY['CRITICAL', 'DECLINING', 'STABLE', 'ACCELERATING', 'PROGRESSING'])
    AND r.intervention_priority_class = ANY (ARRAY['PRIORITY_CRITICAL', 'PRIORITY_HIGH', 'PRIORITY_STANDARD'])
ORDER BY
    CASE r.trajectory_class
        WHEN 'CRITICAL' THEN 1
        WHEN 'DECLINING' THEN 2
        WHEN 'STABLE' THEN 3
        WHEN 'ACCELERATING' THEN 4
        ELSE 5
    END,
    r.intervention_priority_score DESC;

CREATE UNIQUE INDEX idx_mv_opportunity_pk ON pub.mv_isa_opportunity_catalog (country_iso3, pillar_code);
CREATE INDEX idx_mv_opportunity_country ON pub.mv_isa_opportunity_catalog (country_iso3);
CREATE INDEX idx_mv_opportunity_pillar ON pub.mv_isa_opportunity_catalog (pillar_code);
CREATE INDEX idx_mv_opportunity_class ON pub.mv_isa_opportunity_catalog (opportunity_class);
CREATE INDEX idx_mv_opportunity_region ON pub.mv_isa_opportunity_catalog (region_code);

COMMIT;

-- Verification post-execution
SELECT COUNT(*) AS total_lignes, COUNT(vision_id) AS lignes_avec_vision
FROM pub.mv_isa_opportunity_catalog;
\d pub.mv_isa_opportunity_catalog
