-- ============================================================
-- OSA Observatory — patch_constraints_indicator_values.sql
-- Sprint 9 — Mai 2026
--
-- Contraintes additionnelles sur ma.indicator_values :
--   1. raw_value NOT NULL en L1 (données brutes obligatoires)
--   2. country_iso3 format 3 lettres majuscules
--   3. year <= 2030 (borne supérieure)
--   4. Suppression doublon confidence_score
-- ============================================================

BEGIN;

-- Vérifier l'état avant ajout
DO $$
DECLARE
    v_raw_null  INTEGER;
    v_iso3_bad  INTEGER;
    v_year_bad  INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_raw_null
    FROM ma.indicator_values WHERE layer_id = 1 AND raw_value IS NULL;

    SELECT COUNT(*) INTO v_iso3_bad
    FROM ma.indicator_values WHERE country_iso3 !~ '^[A-Z]{3}$';

    SELECT COUNT(*) INTO v_year_bad
    FROM ma.indicator_values WHERE year > 2030;

    RAISE NOTICE 'Vérification pré-contraintes :';
    RAISE NOTICE '  L1 raw_value NULL   : %', v_raw_null;
    RAISE NOTICE '  country_iso3 invalides : %', v_iso3_bad;
    RAISE NOTICE '  year > 2030         : %', v_year_bad;

    IF v_raw_null > 0 THEN RAISE EXCEPTION 'L1 contient % raw_value NULL', v_raw_null; END IF;
    IF v_iso3_bad > 0 THEN RAISE EXCEPTION '% country_iso3 invalides', v_iso3_bad; END IF;
    IF v_year_bad > 0 THEN RAISE EXCEPTION '% valeurs year > 2030', v_year_bad; END IF;
END;
$$;

-- 1. raw_value obligatoire en L1
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_l1_raw_value_not_null
CHECK (layer_id != 1 OR raw_value IS NOT NULL);

-- 2. country_iso3 format ISO 3166-1 alpha-3
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_country_iso3_format
CHECK (country_iso3 ~ '^[A-Z]{3}$');

-- 3. year <= 2030
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_year_upper_bound
CHECK (year <= 2030);

-- 4. Supprimer doublon confidence_score
--    Garder chk_confidence_score (plus explicite), supprimer l'ancien
ALTER TABLE ma.indicator_values
DROP CONSTRAINT IF EXISTS indicator_values_confidence_score_check;

-- Vérification finale
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Contraintes ajoutées :';
    RAISE NOTICE '  chk_l1_raw_value_not_null   — raw_value obligatoire en L1';
    RAISE NOTICE '  chk_country_iso3_format      — format ISO3 3 majuscules';
    RAISE NOTICE '  chk_year_upper_bound         — year <= 2030';
    RAISE NOTICE 'Doublon supprimé :';
    RAISE NOTICE '  indicator_values_confidence_score_check';
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
