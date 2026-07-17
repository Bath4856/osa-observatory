-- ============================================================
-- Mise a jour finding #44 -- IN_PROGRESS (schema Phase 1 construit
-- sur DEV le 17 juillet 2026, pas encore valide ni deploye sur
-- PREPROD/PROD -- ne pas marquer RESOLVED avant validation complete).
-- ============================================================
-- A executer sur osa_db (le registre GAF vit uniquement sur prod)
-- ============================================================

UPDATE ops.audit_findings
SET status = 'IN_PROGRESS'
WHERE finding_code = 'PILLAR_CHAIN_SCHEMA_MISSING_BLOCKS_OIM';

SELECT finding_id, finding_code, status, updated_at
FROM ops.audit_findings
WHERE finding_code = 'PILLAR_CHAIN_SCHEMA_MISSING_BLOCKS_OIM';
