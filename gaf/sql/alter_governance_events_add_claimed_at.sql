-- ============================================================
-- ADR-004 -- Ajustement de schéma : colonne claimed_at
-- Bug découvert en test réel le 14 juillet 2026 (test de concurrence,
-- exigence 4 du finding GAF #39) : l'interruption brutale de deux
-- instances concurrentes du synchroniseur (SIGTTIN suite à un piège de
-- shell, docker exec -i en arrière-plan) a laissé un événement bloqué
-- en IN_PROGRESS sans aucune reprise automatique possible, le
-- synchroniseur ne relisant que PENDING/FAILED.
--
-- Correction : ajout de claimed_at, horodaté au moment de la
-- réservation. Un événement IN_PROGRESS n'est repris que si ce verrou
-- date de plus de 2 minutes (largement supérieur au timeout HTTP de
-- 15s de apply_event()) -- distingue un verrou orphelin (crash) d'un
-- verrou actif (traitement en cours par une autre instance légitime),
-- préservant la protection contre le traitement concurrent déjà en
-- place (FOR UPDATE SKIP LOCKED).
-- 14 juillet 2026 -- osa_preprod uniquement à ce stade.
-- ============================================================

BEGIN;

ALTER TABLE mg.governance_events ADD COLUMN claimed_at timestamp;

COMMIT;

-- Vérification post-exécution
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'mg' AND table_name = 'governance_events' AND column_name = 'claimed_at';
