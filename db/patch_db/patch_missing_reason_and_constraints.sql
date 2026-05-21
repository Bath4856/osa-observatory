-- ============================================================
-- OSA Observatory — patch_missing_reason_and_constraints.sql
-- Sprint 9 — Mai 2026
--
-- 1. Ajout colonne missing_reason VARCHAR(100) sur indicator_values
-- 2. Correction value_status OBSERVED → MISSING pour raw_value NULL
-- 3. Renseignement missing_reason selon le contexte
-- 4. Contraintes additionnelles (v2 corrigée)
--
-- Valeurs missing_reason :
--   SOURCE_NOT_AVAILABLE  — source n'a pas publié pour ce pays/année
--   COUNTRY_NOT_COVERED   — pays hors périmètre de la source cette année
--   DATA_SUPPRESSED       — donnée supprimée par la source (confidentialité)
--   COLLECTION_PENDING    — données attendues, collecte non encore faite
--   CONFLICT_FRAGILITY    — État en situation de conflit/fragmentation
--                           institutionnelle — données structurellement absentes
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Ajouter la colonne missing_reason
-- ------------------------------------------------------------

ALTER TABLE ma.indicator_values
ADD COLUMN IF NOT EXISTS missing_reason VARCHAR(100) DEFAULT NULL;

COMMENT ON COLUMN ma.indicator_values.missing_reason IS
'Raison de l''absence de raw_value. NULL si raw_value présent.
Valeurs : SOURCE_NOT_AVAILABLE, COUNTRY_NOT_COVERED,
DATA_SUPPRESSED, COLLECTION_PENDING, CONFLICT_FRAGILITY.
Conforme Doctrine OSA v1 — traçabilité des données manquantes.';

-- ------------------------------------------------------------
-- 2. Corriger value_status OBSERVED → MISSING pour raw_value NULL
--    Ces lignes ont quality_flag=MISSING mais value_status=OBSERVED
--    (incohérence historique du fetcher)
-- ------------------------------------------------------------

UPDATE ma.indicator_values
SET value_status = 'MISSING'
WHERE layer_id = 1
  AND raw_value IS NULL
  AND value_status = 'OBSERVED'
  AND quality_flag = 'MISSING';

DO $$
DECLARE v_nb INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb FROM ma.indicator_values
    WHERE layer_id = 1 AND raw_value IS NULL AND value_status = 'OBSERVED';
    RAISE NOTICE 'OBSERVED + raw_value NULL résiduels : %', v_nb;
    IF v_nb > 0 THEN RAISE EXCEPTION '% incohérences OBSERVED/NULL résiduelles', v_nb; END IF;
END;
$$;

-- ------------------------------------------------------------
-- 3. Renseigner missing_reason selon le contexte
-- ------------------------------------------------------------

-- 3a. États en situation de conflit/fragmentation (SSD, SDN, SOM, ERI, LBY, CAF, MLI)
--     Données structurellement absentes de nombreuses sources
UPDATE ma.indicator_values
SET missing_reason = 'CONFLICT_FRAGILITY'
WHERE layer_id = 1
  AND raw_value IS NULL
  AND country_iso3 IN ('SSD','SDN','SOM','ERI','LBY','CAF','MLI','COD','ZWE','BDI');

-- 3b. Reste des NULL L1 — source non disponible pour ce pays/année
UPDATE ma.indicator_values
SET missing_reason = 'SOURCE_NOT_AVAILABLE'
WHERE layer_id = 1
  AND raw_value IS NULL
  AND missing_reason IS NULL;

-- ------------------------------------------------------------
-- 4. Contraintes additionnelles
-- ------------------------------------------------------------

-- 4a. OBSERVED ne peut pas avoir raw_value NULL (cohérence sémantique)
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_observed_raw_value_not_null
CHECK (value_status != 'OBSERVED' OR raw_value IS NOT NULL);

-- 4b. missing_reason obligatoire si raw_value NULL en L1
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_l1_missing_reason
CHECK (layer_id != 1 OR raw_value IS NOT NULL OR missing_reason IS NOT NULL);

-- 4c. country_iso3 format ISO 3166-1 alpha-3
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_country_iso3_format
CHECK (country_iso3 ~ '^[A-Z]{3}$');

-- 4d. year <= 2030
ALTER TABLE ma.indicator_values
ADD CONSTRAINT chk_year_upper_bound
CHECK (year <= 2030);

-- 4e. Supprimer doublon confidence_score
ALTER TABLE ma.indicator_values
DROP CONSTRAINT IF EXISTS indicator_values_confidence_score_check;

-- ------------------------------------------------------------
-- 5. Vérification finale
-- ------------------------------------------------------------

DO $$
DECLARE
    v_null_l1        INTEGER;
    v_no_reason      INTEGER;
    v_conflict       INTEGER;
    v_source_na      INTEGER;
    v_obs_null       INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_null_l1
    FROM ma.indicator_values WHERE layer_id=1 AND raw_value IS NULL;

    SELECT COUNT(*) INTO v_no_reason
    FROM ma.indicator_values WHERE layer_id=1 AND raw_value IS NULL AND missing_reason IS NULL;

    SELECT COUNT(*) INTO v_conflict
    FROM ma.indicator_values WHERE layer_id=1 AND missing_reason='CONFLICT_FRAGILITY';

    SELECT COUNT(*) INTO v_source_na
    FROM ma.indicator_values WHERE layer_id=1 AND missing_reason='SOURCE_NOT_AVAILABLE';

    SELECT COUNT(*) INTO v_obs_null
    FROM ma.indicator_values WHERE value_status='OBSERVED' AND raw_value IS NULL;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'patch_missing_reason_and_constraints';
    RAISE NOTICE '  L1 raw_value NULL total    : %', v_null_l1;
    RAISE NOTICE '  Sans missing_reason        : % (doit être 0)', v_no_reason;
    RAISE NOTICE '  CONFLICT_FRAGILITY         : %', v_conflict;
    RAISE NOTICE '  SOURCE_NOT_AVAILABLE       : %', v_source_na;
    RAISE NOTICE '  OBSERVED + NULL résiduels  : % (doit être 0)', v_obs_null;
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'Contraintes ajoutées :';
    RAISE NOTICE '  chk_observed_raw_value_not_null';
    RAISE NOTICE '  chk_l1_missing_reason';
    RAISE NOTICE '  chk_country_iso3_format';
    RAISE NOTICE '  chk_year_upper_bound';
    RAISE NOTICE 'Doublon supprimé :';
    RAISE NOTICE '  indicator_values_confidence_score_check';
    RAISE NOTICE '============================================';

    IF v_no_reason > 0 THEN RAISE EXCEPTION '% L1 NULL sans missing_reason', v_no_reason; END IF;
    IF v_obs_null > 0  THEN RAISE EXCEPTION '% OBSERVED + NULL résiduels', v_obs_null; END IF;
END;
$$;

COMMIT;
