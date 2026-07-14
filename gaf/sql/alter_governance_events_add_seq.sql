-- ============================================================
-- ADR-004 -- Ajustement de schéma : colonne de séquence
-- Bug découvert en test réel le 14 juillet 2026 : deux événements émis
-- dans la MEME transaction (confirm_email -- AFFILIATE_CONFIRMED puis
-- WORKING_GROUP_ACTIVATED) partagent un created_at strictement
-- identique, NOW() étant figé pour toute la durée d'une transaction
-- PostgreSQL. "ORDER BY created_at" n'a alors aucune garantie d'ordre
-- entre les deux lignes -- WORKING_GROUP_ACTIVATED a été réservé avant
-- AFFILIATE_CONFIRMED lors du premier test réel, provoquant un 409
-- ("Affilié inconnu") côté cible.
-- Correction : colonne seq (BIGSERIAL), incrémentée par une séquence
-- dédiée, garantit l'ordre réel d'insertion indépendamment de NOW().
-- 14 juillet 2026 -- osa_preprod uniquement à ce stade.
-- ============================================================

BEGIN;

ALTER TABLE mg.governance_events ADD COLUMN seq BIGSERIAL;

CREATE INDEX IF NOT EXISTS idx_governance_events_seq ON mg.governance_events (seq);

COMMIT;

-- Vérification post-exécution
SELECT event_uuid, event_type, seq, created_at
FROM mg.governance_events
ORDER BY seq;
