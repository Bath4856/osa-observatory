-- ============================================================
-- OSA Observatory — patch_fix_source_id_null.sql
-- Sprint 9 — Chantier 9A — Mai 2026
--
-- Correction source_id NULL sur les trois couches L1/L2/L3
--
-- Origine :
--   L1 : fetcher WB historique avant fix Sprint 8 (commit bf92525)
--   L2 : copie depuis L1 NULL + imputer MICE sans source_id
--   L3 : normalize_indicator() n'insère jamais source_id
--
-- Règle appliquée :
--   L1 : tous les NULL sont WB (source_id = 11) — confirmé audit
--   L2 : idem — proviennent tous d'indicateurs WB
--   L3 : source_id = NULL acceptable pour scores calculés
--        mais on renseigne 11 (WB) pour les indicateurs WB purs
--        et on laisse NULL pour les COMPUTED (pas de source unique)
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Correction L1 — tous NULL → WB (source_id = 11)
-- ------------------------------------------------------------

UPDATE ma.indicator_values
SET source_id = 11
WHERE layer_id = 1
  AND source_id IS NULL;

DO $$
DECLARE v_nb INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb
    FROM ma.indicator_values
    WHERE layer_id = 1 AND source_id IS NULL;
    RAISE NOTICE 'L1 NULL résiduels après correction : %', v_nb;
    IF v_nb > 0 THEN RAISE EXCEPTION 'L1 NULL résiduels — rollback'; END IF;
END;
$$;

-- ------------------------------------------------------------
-- 2. Correction L2 — NULL pour indicateurs WB standard
--    Exclure les COMPUTED (ECO_FORMAL_TRAJECTORY, MIN_LEAKAGE_RISK, etc.)
-- ------------------------------------------------------------

UPDATE ma.indicator_values iv
SET source_id = 11
WHERE iv.layer_id = 2
  AND iv.source_id IS NULL
  AND EXISTS (
      SELECT 1 FROM rf.indicators i
      WHERE i.code = iv.indicator_code
        AND i.imputation_regime != 'COMPUTED'
  );

DO $$
DECLARE v_nb INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb
    FROM ma.indicator_values iv
    WHERE iv.layer_id = 2
      AND iv.source_id IS NULL
      AND EXISTS (
          SELECT 1 FROM rf.indicators i
          WHERE i.code = iv.indicator_code
            AND i.imputation_regime != 'COMPUTED'
      );
    RAISE NOTICE 'L2 NULL résiduels (non-COMPUTED) après correction : %', v_nb;
END;
$$;

-- ------------------------------------------------------------
-- 3. Vérification globale
-- ------------------------------------------------------------

DO $$
DECLARE
    v_l1 INTEGER; v_l2 INTEGER; v_l3 INTEGER;
    v_l1_total INTEGER; v_l2_total INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_l1 FROM ma.indicator_values WHERE layer_id=1 AND source_id IS NULL;
    SELECT COUNT(*) INTO v_l2 FROM ma.indicator_values
    WHERE layer_id=2 AND source_id IS NULL
      AND EXISTS (SELECT 1 FROM rf.indicators WHERE code = indicator_code AND imputation_regime != 'COMPUTED');
    SELECT COUNT(*) INTO v_l3 FROM ma.indicator_values WHERE layer_id=3 AND source_id IS NULL;
    SELECT COUNT(*) INTO v_l1_total FROM ma.indicator_values WHERE layer_id=1;
    SELECT COUNT(*) INTO v_l2_total FROM ma.indicator_values WHERE layer_id=2;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'Chantier 9A — Correction source_id NULL';
    RAISE NOTICE '  L1 NULL résiduels     : % / %', v_l1, v_l1_total;
    RAISE NOTICE '  L2 NULL résiduels     : % (COMPUTED exclus — normal)', v_l2;
    RAISE NOTICE '  L3 NULL résiduels     : % (scores calculés — accepté)', v_l3;
    RAISE NOTICE '============================================';

    IF v_l1 > 0 THEN RAISE EXCEPTION 'L1 NULL résiduels — rollback'; END IF;
END;
$$;

COMMIT;
