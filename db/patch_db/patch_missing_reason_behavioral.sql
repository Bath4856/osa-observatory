-- ============================================================
-- OSA Observatory — patch_missing_reason_behavioral.sql
-- Sprint 9 — Mai 2026
--
-- Correction approche "liste en dur" → condition comportementale ACLED
-- ============================================================

BEGIN;

-- Désactiver temporairement la contrainte pour le reset
ALTER TABLE ma.indicator_values
DROP CONSTRAINT IF EXISTS chk_l1_missing_reason;

-- 1. Réinitialiser les 486 lignes codées en dur
UPDATE ma.indicator_values
SET missing_reason = NULL
WHERE layer_id = 1
  AND raw_value IS NULL
  AND missing_reason = 'CONFLICT_FRAGILITY';

-- 2. CONFLICT_FRAGILITY par condition comportementale ACLED
UPDATE ma.indicator_values iv
SET missing_reason = 'CONFLICT_FRAGILITY'
WHERE iv.layer_id = 1
  AND iv.raw_value IS NULL
  AND iv.missing_reason IS NULL
  AND EXISTS (
      SELECT 1 FROM ma.indicator_values acled
      WHERE acled.indicator_code IN ('GEO_CON', 'GEO_TER')
        AND acled.layer_id = 3
        AND acled.country_iso3 = iv.country_iso3
        AND acled.year = iv.year
        AND acled.processed_value > 0.5
  );

-- 3. SOURCE_NOT_AVAILABLE pour les NULL restants
UPDATE ma.indicator_values
SET missing_reason = 'SOURCE_NOT_AVAILABLE'
WHERE layer_id = 1
  AND raw_value IS NULL
  AND missing_reason IS NULL;

-- 4. Vérifier que tout est renseigné avant de remettre la contrainte
DO $$
DECLARE v_no_reason INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_no_reason FROM ma.indicator_values
    WHERE layer_id=1 AND raw_value IS NULL AND missing_reason IS NULL;
    IF v_no_reason > 0 THEN
        RAISE EXCEPTION '% NULL sans missing_reason — rollback', v_no_reason;
    END IF;
END;
$$;

-- 5. Remettre la contrainte
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_l1_missing_reason
CHECK (layer_id != 1 OR raw_value IS NOT NULL OR missing_reason IS NOT NULL);

-- 6. Vérification finale
DO $$
DECLARE
    v_total INTEGER; v_conflict INTEGER; v_source_na INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total FROM ma.indicator_values WHERE layer_id=1 AND raw_value IS NULL;
    SELECT COUNT(*) INTO v_conflict FROM ma.indicator_values WHERE layer_id=1 AND missing_reason='CONFLICT_FRAGILITY';
    SELECT COUNT(*) INTO v_source_na FROM ma.indicator_values WHERE layer_id=1 AND missing_reason='SOURCE_NOT_AVAILABLE';

    RAISE NOTICE '============================================';
    RAISE NOTICE 'missing_reason — approche comportementale ACLED';
    RAISE NOTICE '  Total NULL L1              : %', v_total;
    RAISE NOTICE '  CONFLICT_FRAGILITY (ACLED) : %', v_conflict;
    RAISE NOTICE '  SOURCE_NOT_AVAILABLE       : %', v_source_na;
    RAISE NOTICE '============================================';
END;
$$;

-- Top pays CONFLICT_FRAGILITY pour validation
SELECT country_iso3,
       COUNT(*) AS nb_null,
       MIN(year) AS annee_min,
       MAX(year) AS annee_max
FROM ma.indicator_values
WHERE layer_id = 1
  AND raw_value IS NULL
  AND missing_reason = 'CONFLICT_FRAGILITY'
GROUP BY country_iso3
ORDER BY nb_null DESC;

COMMIT;
