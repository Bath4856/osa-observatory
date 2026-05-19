-- ============================================================
-- OSA Observatory — patch_deduplicate_l1_only.sql
-- Sprint 8 — Mai 2026
-- Nettoyage 106 884 doublons L1 + ECO_GDP L2
-- ============================================================

BEGIN;

-- 1. Supprimer doublons L1
DELETE FROM ma.indicator_values
WHERE layer_id = 1
  AND id NOT IN (
      SELECT MIN(id)
      FROM ma.indicator_values
      WHERE layer_id = 1
      GROUP BY indicator_code, country_iso3, year, layer_id
  );

DO $$
DECLARE
    v_restants INTEGER;
    v_total    INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_restants
    FROM ma.indicator_values
    WHERE layer_id = 1
      AND id NOT IN (
          SELECT MIN(id) FROM ma.indicator_values
          WHERE layer_id = 1
          GROUP BY indicator_code, country_iso3, year, layer_id
      );
    SELECT COUNT(*) INTO v_total FROM ma.indicator_values WHERE layer_id = 1;
    RAISE NOTICE 'Doublons residuels : % | Total L1 propre : %', v_restants, v_total;
    IF v_restants > 0 THEN RAISE EXCEPTION 'Doublons residuels -- rollback'; END IF;
END;
$$;

-- 2. ECO_GDP L2 copie directe depuis L1
DELETE FROM ma.indicator_values WHERE indicator_code = 'ECO_GDP' AND layer_id = 2;

INSERT INTO ma.indicator_values
    (indicator_code, country_iso3, year, layer_id,
     raw_value, processed_value, source_id,
     confidence_score, is_estimated, quality_flag, value_status)
SELECT
    indicator_code, country_iso3, year, 2,
    raw_value, raw_value, source_id,
    0.95, FALSE, 'OK', 'OBSERVED'
FROM ma.indicator_values
WHERE indicator_code = 'ECO_GDP'
  AND layer_id = 1
  AND year BETWEEN 2010 AND 2024
ON CONFLICT DO NOTHING;

DO $$
DECLARE v_nb INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb FROM ma.indicator_values
    WHERE indicator_code = 'ECO_GDP' AND layer_id = 2;
    RAISE NOTICE 'ECO_GDP L2 : % lignes', v_nb;
END;
$$;

COMMIT;
