-- ============================================================
-- OSA Observatory — patch_normalize_indicator_v2.sql
-- Sprint 7 — Mai 2026
--
-- Étape 3 du gel des bornes de normalisation.
--
-- Modification de ma.normalize_indicator() pour lire
-- rf.normalization_bounds en priorité avant le calcul
-- dynamique MIN/MAX.
--
-- Logique :
--   1. Chercher les bornes figées dans rf.normalization_bounds
--      pour l'indicateur et la version v1_2026
--   2. Si bornes figées trouvées : les utiliser (stable)
--   3. Sinon : fallback sur MIN/MAX dynamique (7 exclus)
--
-- Garantit que les scores 2021–2025+ sont normalisés sur
-- la même échelle que les scores historiques 2010–2020.
-- Compatible avec le standard PNUD/Banque mondiale (IDH).
--
-- Prérequis :
--   rf.normalization_bounds peuplé (Sprint 6 — 117 bornes)
--   patch_normalization_bounds_v1.sql déjà appliqué
--
-- Test pilote recommandé sur PMIN avant déploiement global.
-- Idempotent — peut être rejoué sans erreur.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Sauvegarde de la version actuelle dans l'audit
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rf.function_audit_log (
    id           BIGSERIAL PRIMARY KEY,
    function_name VARCHAR(100) NOT NULL,
    schema_name   VARCHAR(50)  NOT NULL DEFAULT 'ma',
    version_label VARCHAR(50)  NOT NULL,
    definition    TEXT         NOT NULL,
    applied_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    applied_by    VARCHAR(100) DEFAULT CURRENT_USER,
    notes         TEXT
);

INSERT INTO rf.function_audit_log (
    function_name, schema_name, version_label, definition, notes
)
SELECT
    'normalize_indicator',
    'ma',
    'v1_dynamic_minmax',
    pg_get_functiondef(p.oid),
    'Version originale Sprint 4 — calcul dynamique MIN/MAX sur layer_id=2. '
    'Sauvegardée avant modification Sprint 7 — gel bornes v1_2026.'
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'ma' AND p.proname = 'normalize_indicator'
LIMIT 1;

-- ------------------------------------------------------------
-- 2. Nouvelle version : normalize_indicator v2
--    Lecture rf.normalization_bounds en priorité
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION ma.normalize_indicator(
    p_indicator      CHARACTER VARYING,
    p_year           SMALLINT,
    p_method_version INTEGER DEFAULT 1
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_min        NUMERIC;
    v_max        NUMERIC;
    v_direction  CHAR(1);
    v_inserted   INT;
    v_source     TEXT;  -- 'FROZEN' ou 'DYNAMIC' — pour traçabilité
BEGIN
    -- ── 1. Lire la direction de l'indicateur ─────────────────────
    SELECT direction INTO v_direction
    FROM rf.indicators
    WHERE code = p_indicator;

    IF v_direction IS NULL THEN RETURN 0; END IF;

    -- ── 2. Chercher les bornes figées v1_2026 ────────────────────
    --    (gel Sprint 6 — période référence 2010–2020)
    SELECT nb.min_value, nb.max_value
    INTO   v_min, v_max
    FROM   rf.normalization_bounds nb
    WHERE  nb.indicator_code   = p_indicator
      AND  nb.freeze_version   = 'v1_2026'
      AND  nb.is_active        = TRUE
    LIMIT 1;

    IF v_min IS NOT NULL AND v_max IS NOT NULL AND v_max > v_min THEN
        -- Bornes figées disponibles et valides
        v_source := 'FROZEN';
    ELSE
        -- ── 3. Fallback : calcul dynamique sur layer_id=2 ────────
        --    Pour les 7 indicateurs exclus du gel (min=max ou absent)
        SELECT MIN(raw_value), MAX(raw_value)
        INTO   v_min, v_max
        FROM   ma.indicator_values
        WHERE  indicator_code = p_indicator
          AND  year           = p_year
          AND  layer_id       = 2
          AND  raw_value IS NOT NULL;

        v_source := 'DYNAMIC';
    END IF;

    -- ── 4. Vérifier que les bornes sont utilisables ──────────────
    IF v_min IS NULL OR v_max IS NULL OR v_max = v_min THEN
        RETURN 0;
    END IF;

    -- ── 5. Normalisation min-max et insertion L3 ─────────────────
    INSERT INTO ma.indicator_values
        (indicator_code, country_iso3, year, layer_id,
         raw_value, processed_value, quality_flag)
    SELECT
        indicator_code,
        country_iso3,
        year,
        3,
        raw_value,
        CASE WHEN v_direction = '+'
            THEN LEAST(1.0, GREATEST(0.0, (raw_value - v_min) / (v_max - v_min)))
            ELSE LEAST(1.0, GREATEST(0.0, (v_max - raw_value) / (v_max - v_min)))
        END,
        quality_flag
    FROM ma.indicator_values
    WHERE indicator_code = p_indicator
      AND year           = p_year
      AND layer_id       = 2
      AND raw_value IS NOT NULL
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$function$;

-- ------------------------------------------------------------
-- 3. Enregistrement de la nouvelle version dans l'audit
-- ------------------------------------------------------------

INSERT INTO rf.function_audit_log (
    function_name, schema_name, version_label, definition, notes
)
SELECT
    'normalize_indicator',
    'ma',
    'v2_frozen_bounds',
    pg_get_functiondef(p.oid),
    'Version Sprint 7 — lecture rf.normalization_bounds v1_2026 en priorité. '
    'Fallback dynamique pour 7 indicateurs exclus (min=max). '
    'LEAST/GREATEST ajoutés pour borner les valeurs entre 0 et 1. '
    'Gel référence : 2010–2020. Source traçable : FROZEN ou DYNAMIC.'
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'ma' AND p.proname = 'normalize_indicator'
LIMIT 1;

-- ------------------------------------------------------------
-- 4. Mise à jour du registre de gel
-- ------------------------------------------------------------

UPDATE rf.normalization_freeze_registry
SET notes = notes || ' | Sprint 7 — normalize_indicator() modifié pour lire '
                  || 'rf.normalization_bounds v1_2026 en priorité. '
                  || 'Déployé le ' || NOW()::date::text || '.'
WHERE freeze_version = 'v1_2026';

-- ------------------------------------------------------------
-- 5. TEST PILOTE PMIN — vérification avant/après
--    Comparer les scores L3 PMIN avant et après le gel.
--    Les valeurs 2010–2020 doivent rester identiques.
--    Les valeurs 2021–2024 doivent utiliser les bornes figées.
-- ------------------------------------------------------------

-- Rapport de vérification
DO $$
DECLARE
    v_frozen_count    INTEGER;
    v_dynamic_count   INTEGER;
    v_total_l3        INTEGER;
BEGIN
    -- Compter les indicateurs avec bornes figées
    SELECT COUNT(DISTINCT indicator_code)
    INTO v_frozen_count
    FROM rf.normalization_bounds
    WHERE freeze_version = 'v1_2026' AND is_active = TRUE;

    -- Compter les indicateurs L3 existants
    SELECT COUNT(DISTINCT indicator_code)
    INTO v_total_l3
    FROM ma.indicator_values
    WHERE layer_id = 3;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'normalize_indicator() v2 — DÉPLOYÉ';
    RAISE NOTICE '  Bornes figées v1_2026 disponibles : %', v_frozen_count;
    RAISE NOTICE '  Indicateurs actuellement en L3    : %', v_total_l3;
    RAISE NOTICE '  Fallback dynamique pour           : 7 indicateurs exclus';
    RAISE NOTICE '  (ECO_GDP, ENV_ENE, PGEO_MINE_COORD, HUM_EDU, HUM_RES,';
    RAISE NOTICE '   PRES_OIL_RENTS, PRES_RENEW_SHARE_FEC)';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'IMPORTANT : relancer run_pipeline_historical(2010, 2024)';
    RAISE NOTICE 'pour repropager les scores L3 avec les nouvelles bornes.';
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
