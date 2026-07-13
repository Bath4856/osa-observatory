-- ============================================================
-- Sous-chantier B -- Statut d'activation post-propagation
-- 12 juillet 2026
-- ============================================================
-- PROD_PENDING_ACTIVATION : statut distinct pour un compte cree par
-- propagation PREPROD -> PROD, avant que la personne n'ait defini son
-- mot de passe en production. Semantique volontairement differente de
-- "mot de passe oublie" -- ce compte n'a jamais eu de mot de passe en
-- prod, ce n'est pas une reinitialisation.
-- ============================================================
-- EXECUTION -- sur osa_db (cible de la propagation) ET osa_preprod
-- (coherence de schema entre environnements, meme si ce statut n'y est
-- pas utilise directement) :
--   docker exec -i osa-db psql -U postgres -d <base> \
--     < sub_b_prod_pending_activation_status.sql
-- ============================================================

BEGIN;

ALTER TABLE mg.affiliates DROP CONSTRAINT chk_affiliate_status;

ALTER TABLE mg.affiliates ADD CONSTRAINT chk_affiliate_status
    CHECK (status::text = ANY (ARRAY[
        'PENDING_EMAIL', 'AFFILIATED', 'PENDING', 'ACTIVE',
        'SUSPENDED', 'WITHDRAWN', 'REJECTED', 'PROD_PENDING_ACTIVATION'
    ]::text[]));

COMMIT;

SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'chk_affiliate_status';
