
BEGIN;

-- ============================================================
-- OSA Observatory -- Sprint 20
-- Étape 1 : Matérialisation pub.v_isa_opportunity_catalog
-- 107s -> <5ms
-- ============================================================

DROP VIEW IF EXISTS pub.v_isa_opportunity_catalog;

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
        WHEN r.trajectory_class = 'CRITICAL'
             AND r.intervention_priority_class = 'PRIORITY_CRITICAL'
             THEN 'HIGH_IMPACT_OPPORTUNITY'
        WHEN r.trajectory_class IN ('CRITICAL','DECLINING')
             AND r.intervention_priority_class IN ('PRIORITY_CRITICAL','PRIORITY_HIGH')
             THEN 'SIGNIFICANT_OPPORTUNITY'
        WHEN r.trajectory_class = 'STABLE'
             AND r.intervention_priority_class = 'PRIORITY_HIGH'
             THEN 'UNLOCK_OPPORTUNITY'
        ELSE 'MONITORING_OPPORTUNITY'
    END AS opportunity_class,
    CASE
        WHEN r.trajectory_class = 'CRITICAL'  THEN 'Strong positive delta achievable -- see feasibility study'
        WHEN r.trajectory_class = 'DECLINING' THEN 'Moderate positive delta achievable -- see feasibility study'
        WHEN r.trajectory_class = 'STABLE'    THEN 'Unlock potential identified -- see feasibility study'
        ELSE 'Consolidation delta achievable'
    END AS delta_potential_label,
    r.trajectory_class,
    r.intervention_priority_class,
    ROUND(r.intervention_priority_score::numeric, 4) AS intervention_priority_score,
    ca.region_code,
    rg.name_fr AS region_label,
    'This opportunity has been identified by the OSA P7J engine. Contact OSA for a full feasibility study.'::text AS feasibility_call,
    'OSA Observatory -- CC-BY-NC-4.0'::text AS source
FROM ma.v_p7j_recommendation_engine r
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = r.country_iso3
LEFT JOIN rf.regions rg ON rg.code = ca.region_code
WHERE r.year = (SELECT MAX(year) FROM ma.v_p7j_recommendation_engine)
  AND r.trajectory_class IN ('CRITICAL','DECLINING','STABLE','ACCELERATING','PROGRESSING')
  AND r.intervention_priority_class IN ('PRIORITY_CRITICAL','PRIORITY_HIGH','PRIORITY_STANDARD')
ORDER BY
    CASE r.trajectory_class
        WHEN 'CRITICAL'     THEN 1
        WHEN 'DECLINING'    THEN 2
        WHEN 'STABLE'       THEN 3
        WHEN 'ACCELERATING' THEN 4
        ELSE 5
    END,
    r.intervention_priority_score DESC;

-- Index critiques pour le portail
CREATE UNIQUE INDEX idx_mv_opportunity_pk
    ON pub.mv_isa_opportunity_catalog (country_iso3, pillar_code);
CREATE INDEX idx_mv_opportunity_country
    ON pub.mv_isa_opportunity_catalog (country_iso3);
CREATE INDEX idx_mv_opportunity_pillar
    ON pub.mv_isa_opportunity_catalog (pillar_code);
CREATE INDEX idx_mv_opportunity_class
    ON pub.mv_isa_opportunity_catalog (opportunity_class);
CREATE INDEX idx_mv_opportunity_region
    ON pub.mv_isa_opportunity_catalog (region_code);

COMMENT ON MATERIALIZED VIEW pub.mv_isa_opportunity_catalog IS
    'Catalogue opportunites souveraines -- Sprint 20. '
    'Remplace pub.v_isa_opportunity_catalog (107s). '
    'Source : ma.v_p7j_recommendation_engine. '
    'Refresh apres integration donnees.';

COMMIT;
