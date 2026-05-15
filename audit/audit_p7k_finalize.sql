\echo ''
\echo '========================================='
\echo ' OSA / ISA — AUDIT P7K FINALIZATION'
\echo '========================================='

--------------------------------------------------
-- MATERIALIZED VIEW CHECK
--------------------------------------------------

SELECT
    COUNT(*) AS mv_rows
FROM ma.mv_isa_executive_master_board;

--------------------------------------------------
-- NULL CHECK
--------------------------------------------------

SELECT
    COUNT(*) AS critical_nulls
FROM ma.mv_isa_executive_master_board
WHERE executive_priority_score IS NULL
OR sovereign_execution_pressure IS NULL;

--------------------------------------------------
-- BOUNDS CHECK
--------------------------------------------------

SELECT
    COUNT(*) AS invalid_scores
FROM ma.mv_isa_executive_master_board
WHERE executive_priority_score < 0
OR executive_priority_score > 1;

--------------------------------------------------
-- GOVERNANCE REGISTRY
--------------------------------------------------

SELECT
    package_code,
    package_status,
    package_version,
    production_ready,
    freeze_ready

FROM mg.package_governance_registry
WHERE package_code='P7K';

--------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------

SELECT
    dependency_package,
    dependency_type

FROM mg.package_dependency_registry
WHERE package_code='P7K'

ORDER BY dependency_package;

--------------------------------------------------
-- FINAL AUDIT STATUS
--------------------------------------------------

SELECT
CASE
    WHEN EXISTS (
        SELECT 1
        FROM ma.mv_isa_executive_master_board
        WHERE executive_priority_score IS NULL
    )
    THEN 'AUDIT_KO'

    ELSE 'AUDIT_OK'
END AS p7k_audit_status;

\echo ''
\echo '✅ AUDIT COMPLETE'