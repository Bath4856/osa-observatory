-- ============================================================
-- Mise a jour findings #42 et #44 -- RESOLVED
-- Schemas ADR-004 Phase 1 et OIM Phase 1 deployes et valides sur les
-- trois environnements (DEV, PREPROD, PROD) le 17 juillet 2026.
-- ============================================================

UPDATE ops.audit_findings
SET status = 'RESOLVED'
WHERE finding_code IN ('OIM_ENGINE_CREATION', 'PILLAR_CHAIN_SCHEMA_MISSING_BLOCKS_OIM');

SELECT finding_id, finding_code, status, updated_at
FROM ops.audit_findings
WHERE finding_code IN ('OIM_ENGINE_CREATION', 'PILLAR_CHAIN_SCHEMA_MISSING_BLOCKS_OIM')
ORDER BY finding_id;
