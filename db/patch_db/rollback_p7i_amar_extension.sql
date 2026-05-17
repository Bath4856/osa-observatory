-- ============================================================
-- OSA / ISA — Rollback P7I-AMAR
-- Removes AMAR extension only. Does not touch P7I Core.
-- ============================================================

BEGIN;

DROP VIEW IF EXISTS mg.v_public_p7i_amar_alerts;
DROP VIEW IF EXISTS ma.v_p7i_amar_dashboard;
DROP VIEW IF EXISTS ma.v_p7i_amar_atrocity_precursor_engine;

DELETE FROM mg.early_warning_alerts
WHERE source_engine = 'P7I-AMAR';

DELETE FROM mg.risk_taxonomy
WHERE risk_code IN ('ATROCITY_PRECURSOR', 'CIVILIAN_PROTECTION');

DELETE FROM mg.package_registry
WHERE package_code = 'P7I-AMAR';

COMMIT;
