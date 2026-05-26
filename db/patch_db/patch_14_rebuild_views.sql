-- ============================================================
-- OSA Observatory -- Sprint 14
-- Reconstruction vues pub.* manquantes apres CASCADE Sprint 12
--
-- Vues reconstruites :
--   pub.v_isa_country_rankings    -- classement ISA pays
--   pub.v_isa_sovereign_fragility -- fragility engine
--   pub.v_isa_p7z_country_readiness  -- readiness P7Z
--   pub.v_isa_p7z_execution_signals  -- signaux execution P7Z
--
-- Sources :
--   ma.v_isa_observed_scores_by_country_year
--   ma.v_p7j_recommendation_engine
--   ma.v_isa_fragility_warning_engine
--   rf.isa_p7z_baseline_registry
--   rf.v_country_aliases
--   rf.regions
-- ============================================================

BEGIN;

-- ── 1. pub.v_isa_country_rankings ────────────────────────────
DROP VIEW IF EXISTS pub.v_isa_country_rankings CASCADE;
CREATE VIEW pub.v_isa_country_rankings AS
SELECT
    s.country_iso3,
    s.year,
    COALESCE(ca.region_code, s.region_code)             AS region_code,
    COALESCE(rg.name_fr, s.region_label)                AS region_label,
    ROUND(s.isa_observed_score::numeric, 4)             AS isa_observed_score,
    ROUND(s.sovereignty_observed_score::numeric, 4)     AS sovereignty_score,
    ROUND(s.vulnerability_observed_score::numeric, 4)   AS vulnerability_score,
    ROUND(s.resilience_observed_score::numeric, 4)      AS resilience_score,
    ROUND(s.avg_observation_confidence::numeric, 4)     AS data_confidence,
    s.nb_pillars_observed,
    -- Rang ISA par annee
    RANK() OVER (
        PARTITION BY s.year
        ORDER BY s.isa_observed_score DESC NULLS LAST
    )                                                   AS isa_rank,
    -- Rang regional par annee
    RANK() OVER (
        PARTITION BY s.year, COALESCE(ca.region_code, s.region_code)
        ORDER BY s.isa_observed_score DESC NULLS LAST
    )                                                   AS regional_rank,
    -- Trajectoire P7J agregee
    ROUND(AVG(p.intervention_priority_score)::numeric, 4) AS avg_priority_score,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'ACCELERATING') AS nb_pillars_accelerating,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'CRITICAL')     AS nb_pillars_critical,
    -- Momentum
    CASE
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
        THEN 'POSITIVE_MOMENTUM'
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
        THEN 'NEGATIVE_MOMENTUM'
        ELSE 'MIXED_MOMENTUM'
    END                                                 AS sovereign_momentum,
    s.publication_status
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = s.country_iso3
LEFT JOIN rf.regions rg ON rg.code = ca.region_code
LEFT JOIN ma.v_p7j_recommendation_engine p
    ON  p.country_iso3 = s.country_iso3
    AND p.year         = s.year
WHERE s.publication_status = 'OFFICIAL_CONSOLIDATED'
GROUP BY
    s.country_iso3, s.year, ca.region_code, rg.name_fr,
    s.region_code, s.region_label, s.isa_observed_score,
    s.sovereignty_observed_score, s.vulnerability_observed_score,
    s.resilience_observed_score, s.avg_observation_confidence,
    s.nb_pillars_observed, s.publication_status;

COMMENT ON VIEW pub.v_isa_country_rankings IS
'Sprint 14 -- Classement ISA par pays et par annee.
Rang global + rang regional + trajectoire P7J agregee.
Source : ma.v_isa_observed_scores_by_country_year + ma.v_p7j_recommendation_engine.
Reconstruction apres CASCADE Sprint 12.';

-- ── 2. pub.v_isa_sovereign_fragility ─────────────────────────
DROP VIEW IF EXISTS pub.v_isa_sovereign_fragility CASCADE;
CREATE VIEW pub.v_isa_sovereign_fragility AS
SELECT
    f.country_iso3,
    f.year,
    COALESCE(ca.region_code, 'UNSPECIFIED')             AS region_code,
    COALESCE(rg.name_fr, 'Non specifie')                AS region_label,
    ROUND(AVG(f.fragility_warning_score)::numeric, 4)   AS sovereign_fragility_score,
    ROUND(AVG(f.early_warning_score)::numeric, 4)       AS avg_early_warning_score,
    ROUND(AVG(f.stress_propagation_score)::numeric, 4)  AS avg_stress_propagation,
    -- Classe de fragility agregee
    CASE
        WHEN AVG(f.fragility_warning_score) >= 0.70 THEN 'HIGH_FRAGILITY'
        WHEN AVG(f.fragility_warning_score) >= 0.50 THEN 'ELEVATED_FRAGILITY'
        WHEN AVG(f.fragility_warning_score) >= 0.30 THEN 'MODERATE_FRAGILITY'
        ELSE                                              'LOW_FRAGILITY'
    END                                                 AS fragility_class,
    -- Niveau d alerte dominant
    MODE() WITHIN GROUP (ORDER BY f.sovereign_alert_level) AS dominant_alert_level,
    -- Classe early warning dominante
    MODE() WITHIN GROUP (ORDER BY f.early_warning_class)   AS dominant_early_warning_class,
    COUNT(DISTINCT f.pillar_code)                       AS nb_pillars_assessed,
    COUNT(*) FILTER (WHERE f.fragility_warning_class = 'HIGH_FRAGILITY') AS nb_high_fragility_pillars
FROM ma.v_isa_fragility_warning_engine f
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = f.country_iso3
LEFT JOIN rf.regions rg ON rg.code = ca.region_code
WHERE f.year >= 2020
GROUP BY f.country_iso3, f.year, ca.region_code, rg.name_fr
ORDER BY f.year DESC, AVG(f.fragility_warning_score) DESC;

COMMENT ON VIEW pub.v_isa_sovereign_fragility IS
'Sprint 14 -- Fragilite souveraine par pays 2020-2024.
Source : ma.v_isa_fragility_warning_engine.
Reconstruction apres CASCADE Sprint 12.';

-- ── 3. pub.v_isa_p7z_country_readiness ───────────────────────
DROP VIEW IF EXISTS pub.v_isa_p7z_country_readiness CASCADE;
CREATE VIEW pub.v_isa_p7z_country_readiness AS
SELECT
    b.country_iso3,
    b.year,
    COALESCE(ca.region_code, 'UNSPECIFIED')             AS region_code,
    COALESCE(rg.name_fr, 'Non specifie')                AS region_label,
    -- Agregation par pays/annee depuis rf.isa_p7z_baseline_registry
    COUNT(DISTINCT b.pillar_code)                       AS nb_pillars_assessed,
    ROUND(AVG(b.execution_maturity_score)::numeric, 4)  AS avg_execution_maturity,
    ROUND(AVG(b.executive_priority_score)::numeric, 4)  AS avg_executive_priority,
    ROUND(AVG(b.sovereign_execution_pressure)::numeric, 4) AS avg_execution_pressure,
    ROUND(AVG(b.calibration_uncertainty_score)::numeric, 4) AS avg_uncertainty,
    ROUND(AVG(b.predictive_gap_score)::numeric, 4)      AS avg_predictive_gap,
    -- Signaux d execution
    COUNT(*) FILTER (
        WHERE b.predictive_execution_status IN
              ('HIGH_PROBABILITY', 'CONVERGENCE_IMMINENT')
    )                                                   AS nb_simulation_ready,
    COUNT(*) FILTER (
        WHERE b.predictive_execution_status = 'CONVERGENCE_IMMINENT'
    )                                                   AS nb_convergence_imminent,
    -- Classe de readiness aggregee
    CASE
        WHEN COUNT(*) FILTER (
            WHERE b.predictive_execution_status IN
                  ('HIGH_PROBABILITY','CONVERGENCE_IMMINENT')
        ) >= 3 THEN 'HIGH_READINESS'
        WHEN COUNT(*) FILTER (
            WHERE b.predictive_execution_status IN
                  ('HIGH_PROBABILITY','CONVERGENCE_IMMINENT')
        ) >= 1 THEN 'PARTIAL_READINESS'
        ELSE 'LOW_READINESS'
    END                                                 AS predictive_readiness_class,
    -- Score ISA observe
    ROUND(s.isa_observed_score::numeric, 4)             AS isa_observed_score,
    b.baseline_version
FROM rf.isa_p7z_baseline_registry b
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = b.country_iso3
LEFT JOIN rf.regions rg ON rg.code = ca.region_code
LEFT JOIN ma.v_isa_observed_scores_by_country_year s
    ON  s.country_iso3       = b.country_iso3
    AND s.year               = b.year
    AND s.publication_status = 'OFFICIAL_CONSOLIDATED'
WHERE b.year >= 2020
GROUP BY
    b.country_iso3, b.year, ca.region_code, rg.name_fr,
    s.isa_observed_score, b.baseline_version
ORDER BY b.year DESC, avg_execution_maturity DESC;

COMMENT ON VIEW pub.v_isa_p7z_country_readiness IS
'Sprint 14 -- Readiness predictive P7Z par pays 2020-2024.
Source : rf.isa_p7z_baseline_registry (8091 lignes intactes).
Reconstruction apres CASCADE Sprint 12.';

-- ── 4. pub.v_isa_p7z_execution_signals ───────────────────────
DROP VIEW IF EXISTS pub.v_isa_p7z_execution_signals CASCADE;
CREATE VIEW pub.v_isa_p7z_execution_signals AS
SELECT
    b.country_iso3,
    b.year,
    b.pillar_code,
    COALESCE(ca.region_code, 'UNSPECIFIED')             AS region_code,
    b.intervention_family_code,
    b.predictive_execution_status,
    b.executive_master_status,
    ROUND(b.execution_maturity_score::numeric, 4)       AS execution_maturity_score,
    ROUND(b.executive_priority_score::numeric, 4)       AS executive_priority_score,
    ROUND(b.sovereign_execution_pressure::numeric, 4)   AS sovereign_execution_pressure,
    ROUND(b.calibration_uncertainty_score::numeric, 4)  AS calibration_uncertainty,
    ROUND(b.predictive_gap_score::numeric, 4)           AS predictive_gap_score,
    b.cost_calibration_status,
    b.baseline_version,
    -- Signal qualitatif Couche 0
    CASE b.predictive_execution_status
        WHEN 'CONVERGENCE_IMMINENT'  THEN 'STRONG_EXECUTION_SIGNAL'
        WHEN 'HIGH_PROBABILITY'      THEN 'POSITIVE_EXECUTION_SIGNAL'
        WHEN 'MODERATE_PROBABILITY'  THEN 'MODERATE_EXECUTION_SIGNAL'
        ELSE                              'LOW_EXECUTION_SIGNAL'
    END                                                 AS execution_signal_class
FROM rf.isa_p7z_baseline_registry b
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = b.country_iso3
WHERE b.year >= 2020
  AND b.predictive_execution_status IN
      ('HIGH_PROBABILITY', 'CONVERGENCE_IMMINENT', 'MODERATE_PROBABILITY')
ORDER BY b.year DESC,
    CASE b.predictive_execution_status
        WHEN 'CONVERGENCE_IMMINENT' THEN 1
        WHEN 'HIGH_PROBABILITY'     THEN 2
        ELSE 3
    END,
    b.country_iso3, b.pillar_code;

COMMENT ON VIEW pub.v_isa_p7z_execution_signals IS
'Sprint 14 -- Signaux d execution predictive P7Z 2020-2024.
Source : rf.isa_p7z_baseline_registry (8091 lignes intactes).
Filtre sur HIGH_PROBABILITY + CONVERGENCE_IMMINENT + MODERATE_PROBABILITY.
Reconstruction apres CASCADE Sprint 12.';

COMMIT;
