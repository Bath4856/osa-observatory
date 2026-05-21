-- ============================================================
-- OSA Observatory — patch_constraint_l1_source_id.sql
-- Sprint 9 — Mai 2026
--
-- Ajoute une contrainte CHECK qui interdit source_id NULL en L1.
-- L2 et L3 restent libres (COMPUTED, MICE = pas de source unique).
--
-- Prérequis : chantier 9A exécuté (0 NULL en L1)
-- ============================================================

BEGIN;

-- Vérifier que L1 est propre avant d'ajouter la contrainte
DO $$
DECLARE v_nb INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb
    FROM ma.indicator_values
    WHERE layer_id = 1 AND source_id IS NULL;
    IF v_nb > 0 THEN
        RAISE EXCEPTION 'L1 contient encore % lignes NULL — exécuter 9A d''abord', v_nb;
    END IF;
    RAISE NOTICE 'L1 propre — ajout contrainte...';
END;
$$;

-- Ajouter la contrainte
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_l1_source_id_not_null
CHECK (layer_id != 1 OR source_id IS NOT NULL);

-- Vérification
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Contrainte chk_l1_source_id_not_null ajoutée';
    RAISE NOTICE 'Tout INSERT en L1 sans source_id échouera.';
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
