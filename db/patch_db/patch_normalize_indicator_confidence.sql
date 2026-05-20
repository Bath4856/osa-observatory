-- ============================================================
-- OSA Observatory — patch_normalize_indicator_confidence.sql
-- Sprint 8 — Mai 2026
--
-- Problème : normalize_indicator() n'inclut pas confidence_score
-- dans l'INSERT L3 → 51 991 lignes L3 avec confidence_score NULL
-- → vue AMAR classe tous les pays LOW_CONFIDENCE
--
-- Correction : ajouter confidence_score dans SELECT + INSERT
-- depuis layer_id=2 vers layer_id=3
-- ============================================================

CREATE OR REPLACE FUNCTION ma.normalize_indicator(
    p_indicator     character varying,
    p_year          smallint,
    p_method_version integer DEFAULT 1
)
RETURNS integer
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
    SELECT nb.min_value, nb.max_value
    INTO   v_min, v_max
    FROM   rf.normalization_bounds nb
    WHERE  nb.indicator_code = p_indicator
      AND  nb.freeze_version = 'v1_2026'
      AND  nb.is_active      = TRUE
    LIMIT 1;

    IF v_min IS NOT NULL AND v_max IS NOT NULL AND v_max > v_min THEN
        v_source := 'FROZEN';
    ELSE
        -- ── 3. Fallback : calcul dynamique sur layer_id=2 ────────
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
    --      confidence_score propagé depuis L2 → L3
    INSERT INTO ma.indicator_values
        (indicator_code, country_iso3, year, layer_id,
         raw_value, processed_value, quality_flag, confidence_score)
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
        quality_flag,
        COALESCE(confidence_score, 0.700)  -- 0.700 si NULL (données observées sans MICE)
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

-- Vérification
SELECT proname, pronargs FROM pg_proc
WHERE proname = 'normalize_indicator'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'ma');
