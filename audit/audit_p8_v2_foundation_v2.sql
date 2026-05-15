-- =============================================================================
-- OSA / ISA — AUDIT P8 V2 FOUNDATION V2
-- Vérifie : schémas pub.*, MG registries, API contracts, P7Z intégration
-- =============================================================================

\echo ''
\echo '========================================================'
\echo ' OSA / ISA — AUDIT P8 V2 FOUNDATION V2'
\echo '========================================================'

-- -----------------------------------------------------------------------------
-- 1. Vues pub.* — existence et couverture
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 1. Vues pub.* créées ==='
SELECT
    table_name                                          AS pub_view,
    CASE
        WHEN table_name LIKE '%p7z%' OR table_name LIKE '%fragility%'
            THEN 'P7Z_PHASE2'
        WHEN table_name LIKE '%ranking%' OR table_name LIKE '%history%'
            OR table_name LIKE '%latest%' OR table_name LIKE '%pillar%'
            THEN 'ISA_SCORES'
        WHEN table_name LIKE '%opportunity%' OR table_name LIKE '%methodology%'
            OR table_name LIKE '%manifest%'
            THEN 'METADATA'
        ELSE 'OTHER'
    END                                                 AS view_family
FROM information_schema.views
WHERE table_schema = 'pub'
ORDER BY view_family, table_name;

-- -----------------------------------------------------------------------------
-- 2. Release registry
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 2. Release registry P8V2 ==='
SELECT
    release_code, release_label, release_status,
    semantic_version, methodology_version,
    data_period_start, data_period_end,
    TO_CHAR(updated_at, 'YYYY-MM-DD HH24:MI') AS updated_at
FROM mg.release_registry
WHERE release_family = 'P8V2';

-- -----------------------------------------------------------------------------
-- 3. Publication registry — datasets par famille
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 3. Publication registry — datasets ==='
SELECT
    dataset_code, dataset_family, access_class,
    publication_status, source_view,
    LEFT(public_api_path, 45) AS api_path
FROM mg.publication_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY dataset_family, dataset_code;

-- -----------------------------------------------------------------------------
-- 4. API contracts — endpoints par access_class
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 4. API contracts ==='
SELECT
    endpoint_code, http_method, access_class,
    auth_required, contract_status,
    LEFT(api_path, 45) AS api_path
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY access_class, endpoint_code;

-- -----------------------------------------------------------------------------
-- 5. Release manifest via pub.*
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 5. Release manifest ==='
SELECT
    release_code, release_status, semantic_version,
    data_period_start, data_period_end,
    nb_datasets, nb_endpoints,
    nb_public_endpoints, nb_expert_endpoints
FROM pub.v_isa_release_manifest;

-- -----------------------------------------------------------------------------
-- 6. Volumétrie pub.* — toutes les vues
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 6. Volumétrie pub.* ==='
SELECT 'v_isa_country_latest'         AS view_name, COUNT(*) AS rows FROM pub.v_isa_country_latest
UNION ALL
SELECT 'v_isa_country_history',        COUNT(*) FROM pub.v_isa_country_history
UNION ALL
SELECT 'v_isa_country_rankings',       COUNT(*) FROM pub.v_isa_country_rankings
UNION ALL
SELECT 'v_isa_pillar_breakdown',       COUNT(*) FROM pub.v_isa_pillar_breakdown
UNION ALL
SELECT 'v_isa_opportunity_catalog',    COUNT(*) FROM pub.v_isa_opportunity_catalog
UNION ALL
SELECT 'v_isa_release_manifest',       COUNT(*) FROM pub.v_isa_release_manifest
UNION ALL
SELECT 'v_isa_public_methodology',     COUNT(*) FROM pub.v_isa_public_methodology
UNION ALL
SELECT 'v_isa_p7z_country_readiness',  COUNT(*) FROM pub.v_isa_p7z_country_readiness
UNION ALL
SELECT 'v_isa_p7z_execution_signals',  COUNT(*) FROM pub.v_isa_p7z_execution_signals
UNION ALL
SELECT 'v_isa_sovereign_fragility',    COUNT(*) FROM pub.v_isa_sovereign_fragility
ORDER BY view_name;

-- -----------------------------------------------------------------------------
-- 7. P7Z intégration — sample country latest avec P7Z
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 7. Top 10 pays — country_latest enrichi P7Z ==='
SELECT
    country_iso3, latest_year,
    ROUND(isa_score, 3)              AS isa_score,
    country_decision_class,
    sovereign_fragility_class,
    ROUND(avg_exec_probability, 3)   AS avg_exec_prob
FROM pub.v_isa_country_latest
ORDER BY isa_score DESC NULLS LAST
LIMIT 10;

-- -----------------------------------------------------------------------------
-- 8. P7Z readiness — distribution par classe d'éligibilité
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 8. P7Z readiness — distribution ==='
SELECT
    sovereign_fragility_class,
    COUNT(DISTINCT country_iso3)                AS nb_countries,
    COUNT(*)                                    AS nb_country_years,
    ROUND(AVG(avg_execution_probability), 3)    AS avg_exec_prob,
    ROUND(AVG(min_convergence_years), 1)        AS avg_min_conv_years,
    SUM(nb_simulation_ready)                    AS total_simulation_ready
FROM pub.v_isa_p7z_country_readiness
GROUP BY sovereign_fragility_class
ORDER BY avg_exec_prob DESC NULLS LAST;

-- -----------------------------------------------------------------------------
-- 9. Package lifecycle — état de tous les packages P8
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 9. Package lifecycle P8 ==='
SELECT
    package_code, package_status,
    replacement_package,
    TO_CHAR(updated_at, 'YYYY-MM-DD HH24:MI') AS updated_at,
    LEFT(notes, 60) AS notes_short
FROM rf.package_lifecycle
WHERE package_code IN ('P8OPS', 'P8V2', 'P7K', 'P7Z')
ORDER BY package_code;

-- -----------------------------------------------------------------------------
-- 10. Asset registry — statut de migration
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 10. Asset registry — migration status ==='
SELECT
    asset_code, asset_type, classification,
    migration_status,
    current_location, target_location
FROM mg.asset_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY migration_status, asset_code;

-- -----------------------------------------------------------------------------
-- 11. Checks critiques — tous doivent être conformes
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 11. Checks critiques ==='
SELECT
    -- Vues pub.*
    (SELECT COUNT(*) FROM information_schema.views
     WHERE table_schema = 'pub')                        AS pub_views_count,

    -- Vues pub.* P7Z
    (SELECT COUNT(*) FROM information_schema.views
     WHERE table_schema = 'pub'
       AND (table_name LIKE '%p7z%' OR table_name LIKE '%fragility%'))
                                                        AS pub_p7z_views,

    -- Datasets P8V2
    (SELECT COUNT(*) FROM mg.publication_registry
     WHERE release_code = 'P8V2_2026_CANDIDATE')        AS pub_datasets,

    -- API contracts
    (SELECT COUNT(*) FROM mg.api_contract_registry
     WHERE release_code = 'P8V2_2026_CANDIDATE')        AS api_contracts,

    -- Endpoints P7Z
    (SELECT COUNT(*) FROM mg.api_contract_registry
     WHERE release_code = 'P8V2_2026_CANDIDATE'
       AND endpoint_code LIKE '%P7Z%')                  AS p7z_endpoints,

    -- country_latest enrichi (doit avoir des lignes avec exec_prob non NULL)
    (SELECT COUNT(*) FROM pub.v_isa_country_latest
     WHERE avg_exec_probability IS NOT NULL)            AS country_with_p7z,

    -- P7Z readiness rows
    (SELECT COUNT(*) FROM pub.v_isa_p7z_country_readiness) AS p7z_readiness_rows,

    -- Fragility rows
    (SELECT COUNT(*) FROM pub.v_isa_sovereign_fragility)   AS fragility_rows,

    -- Release manifest OK
    (SELECT CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'KO' END
     FROM pub.v_isa_release_manifest
     WHERE release_status = 'ACTIVE_CANDIDATE')         AS release_manifest_status;

-- -----------------------------------------------------------------------------
-- 12. Statut audit final
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 12. Statut audit final ==='
SELECT
    CASE
        WHEN
            (SELECT COUNT(*) FROM information_schema.views
             WHERE table_schema = 'pub') >= 9
        AND (SELECT COUNT(*) FROM mg.publication_registry
             WHERE release_code = 'P8V2_2026_CANDIDATE') >= 10
        AND (SELECT COUNT(*) FROM mg.api_contract_registry
             WHERE release_code = 'P8V2_2026_CANDIDATE') >= 12
        AND (SELECT COUNT(*) FROM pub.v_isa_country_latest) > 0
        AND (SELECT COUNT(*) FROM pub.v_isa_p7z_country_readiness) > 0
        AND (SELECT COUNT(*) FROM pub.v_isa_sovereign_fragility) > 0
        THEN 'AUDIT_OK'
        ELSE 'AUDIT_FAILED'
    END AS p8_v2_audit_status;

\echo ''
\echo '✅ AUDIT P8 V2 FOUNDATION V2 COMPLETE'
\echo ''
