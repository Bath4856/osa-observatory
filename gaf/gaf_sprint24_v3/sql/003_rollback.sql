-- ============================================================
-- OSA ISA – Sprint 24 GAF v3 — Rollback
-- ATTENTION : supprime toutes les données GAF.
-- ============================================================

BEGIN;

DROP TRIGGER IF EXISTS trg_close_finding           ON ops.audit_corrections;
DROP TRIGGER IF EXISTS trg_findings_updated_at     ON ops.audit_findings;
DROP TRIGGER IF EXISTS trg_calibration_updated_at  ON ops.gaf_iprs_calibration;

DROP FUNCTION IF EXISTS ops.close_finding_on_verified_correction();
DROP FUNCTION IF EXISTS ops.set_updated_at();

DROP VIEW IF EXISTS ops.v_gaf_iprs_impact;
DROP VIEW IF EXISTS ops.v_findings_dashboard;
DROP VIEW IF EXISTS ops.v_findings_open;

DROP TABLE IF EXISTS ops.audit_corrections          CASCADE;
DROP TABLE IF EXISTS ops.audit_decisions            CASCADE;
DROP TABLE IF EXISTS ops.audit_recommendations      CASCADE;
DROP TABLE IF EXISTS ops.audit_findings             CASCADE;
DROP TABLE IF EXISTS ops.gaf_iprs_calibration       CASCADE;
DROP TABLE IF EXISTS ops.gaf_orientation_rules      CASCADE;

COMMIT;

SELECT COUNT(*) AS tables_gaf_restantes
FROM pg_tables
WHERE schemaname = 'ops'
  AND tablename IN ('audit_findings','audit_recommendations','audit_decisions',
                    'audit_corrections','gaf_iprs_calibration','gaf_orientation_rules');
