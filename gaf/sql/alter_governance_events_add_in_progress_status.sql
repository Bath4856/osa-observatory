-- ============================================================
-- ADR-004 -- Ajustement de schéma : statut IN_PROGRESS
-- Nécessaire pour satisfaire l'exigence 4 (traitement concurrent) du
-- finding GAF #39 GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS : le
-- synchroniseur doit pouvoir réserver un événement (UPDATE ... SET
-- status = 'IN_PROGRESS' ... RETURNING) avant de l'appliquer, pour
-- qu'une seconde exécution concurrente ne puisse pas ramasser le même
-- événement PENDING/FAILED et le propager deux fois.
-- 14 juillet 2026 -- osa_preprod uniquement à ce stade.
-- ============================================================

BEGIN;

ALTER TABLE mg.governance_events DROP CONSTRAINT governance_events_status_check;

ALTER TABLE mg.governance_events ADD CONSTRAINT governance_events_status_check
    CHECK (status::text = ANY (ARRAY[
        'PENDING', 'IN_PROGRESS', 'PROPAGATED', 'FAILED'
    ]::text[]));

COMMIT;

SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conname = 'governance_events_status_check';
