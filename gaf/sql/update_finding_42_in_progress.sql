-- ============================================================
-- Mise a jour finding #42 -- IN_PROGRESS (schema Phase 1 construit et
-- teste sur DEV le 17 juillet 2026, pas encore deploye sur
-- PREPROD/PROD -- ne pas marquer RESOLVED avant validation complete).
-- ============================================================

UPDATE ops.audit_findings
SET status = 'IN_PROGRESS'
WHERE finding_code = 'OIM_ENGINE_CREATION';

SELECT finding_id, finding_code, status, updated_at
FROM ops.audit_findings
WHERE finding_code = 'OIM_ENGINE_CREATION';
