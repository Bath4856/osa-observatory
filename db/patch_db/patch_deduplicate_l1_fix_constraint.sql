-- ============================================================
-- OSA Observatory — patch_deduplicate_l1_fix_constraint.sql
-- Sprint 8 — Mai 2026
--
-- Problème identifié : la contrainte UNIQUE sur indicator_values
-- inclut method_version_id, permettant des doublons multiples
-- pour le même (indicator_code, country_iso3, year, layer_id).
--
-- Conséquence : 106 884 doublons en L1 qui perturbent MICE.
-- Cause : le fetcher WB a été relancé plusieurs fois avec des
-- method_version_id différents sans déduplication.
--
-- Ce patch :
--   1. Supprime les doublons L1 (garde MIN(id) par groupe)
--   2. Corrige la contrainte UNIQUE pour exclure method_version_id
--   3. Vérifie le résultat
--
-- La table indicator_values est partitionnée par année —
-- la contrainte doit être recréée sur chaque partition.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Nettoyage des doublons L1
-- ------------------------------------------------------------

DO $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM ma.indicator_values
    WHERE layer_id = 1
      AND id NOT IN (
          SELECT MIN(id)
          FROM ma.indicator_values
          WHERE layer_id = 1
          GROUP BY indicator_code, country_iso3, year, layer_id
      );

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE 'Doublons L1 supprimés : %', v_deleted;
END;
$$;

-- ------------------------------------------------------------
-- 2. Vérification post-nettoyage
-- ------------------------------------------------------------

DO $$
DECLARE
    v_remaining INTEGER;
    v_total     INTEGER;
    v_pays      INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_remaining
    FROM ma.indicator_values iv
    WHERE layer_id = 1
      AND id NOT IN (
          SELECT MIN(id)
          FROM ma.indicator_values
          WHERE layer_id = 1
          GROUP BY indicator_code, country_iso3, year, layer_id
      );

    SELECT COUNT(*), COUNT(DISTINCT country_iso3)
    INTO v_total, v_pays
    FROM ma.indicator_values
    WHERE layer_id = 1;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'Post-nettoyage L1 :';
    RAISE NOTICE '  Doublons résiduels  : %', v_remaining;
    RAISE NOTICE '  Total lignes L1     : %', v_total;
    RAISE NOTICE '  Pays couverts       : %', v_pays;
    RAISE NOTICE '============================================';

    IF v_remaining > 0 THEN
        RAISE EXCEPTION 'Doublons résiduels détectés — vérifier manuellement';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 3. Correction de la contrainte UNIQUE
--    La table est partitionnée — la contrainte existe sur la
--    table parent et se propage aux partitions.
--    On vérifie d'abord la structure avant de modifier.
-- ------------------------------------------------------------

DO $$
DECLARE
    v_constraint_name TEXT;
    v_partition_count INTEGER;
BEGIN
    -- Vérifier le nom exact de la contrainte
    SELECT conname INTO v_constraint_name
    FROM pg_constraint
    WHERE conrelid = 'ma.indicator_values'::regclass
      AND contype = 'u'
      AND conname LIKE '%indicator_code%country%year%layer%'
    LIMIT 1;

    IF v_constraint_name IS NULL THEN
        RAISE NOTICE 'Contrainte UNIQUE non trouvée sur table parent — peut être sur partitions';
    ELSE
        RAISE NOTICE 'Contrainte trouvée : %', v_constraint_name;
    END IF;

    -- Compter les partitions
    SELECT COUNT(*) INTO v_partition_count
    FROM pg_inherits
    WHERE inhparent = 'ma.indicator_values'::regclass;

    RAISE NOTICE 'Nombre de partitions : %', v_partition_count;
END;
$$;

-- Supprimer l'ancienne contrainte (sans method_version_id)
-- Note : sur table partitionnée, ALTER TABLE s'applique à toutes les partitions
ALTER TABLE ma.indicator_values
    DROP CONSTRAINT IF EXISTS indicator_values_indicator_code_country_iso3_year_layer_id__key;

-- Recréer sans method_version_id
ALTER TABLE ma.indicator_values
    ADD CONSTRAINT uq_indicator_values_core
    UNIQUE (indicator_code, country_iso3, year, layer_id);

-- ------------------------------------------------------------
-- 4. Vérification de la nouvelle contrainte
-- ------------------------------------------------------------

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'ma.indicator_values'::regclass
  AND contype = 'u'
ORDER BY conname;

COMMIT;
