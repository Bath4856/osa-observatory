-- ============================================================
-- Sprint 26 — Lot C (2/2)
-- Recalcul pipeline PENV après correction ENV_FOR
-- GAF finding #28 ENV_FOR_CORRECTION_PENDING — clôture
-- 23 juin 2026
-- ============================================================
-- PRÉ-REQUIS :
--   1. sprint26_lot_c_env_for.sql exécuté avec succès (147 lignes L1)
--   2. imputer_v3.py exécuté pour ENV_FOR :
--      python3 collectors/imputer_v3.py --indicator ENV_FOR
--      OU pipeline complet option [7] L3 mise à jour annuelle
--      (ce script vérifie que L3 ENV_FOR est bien recalculé)
--
-- EXÉCUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint26_lot_c_recompute_penv.sql
-- ============================================================

BEGIN;

-- ============================================================
-- ÉTAPE 1 — Vérifier que L3 ENV_FOR a bien été recalculé
-- (doit avoir des valeurs entre 0 et 1, pas de 1.000 massif)
-- ============================================================

DO $$
DECLARE
    v_total      INT;
    v_val_1      INT;
    v_val_0      INT;
    v_pct_extr   NUMERIC;
BEGIN
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE processed_value = 1.0),
        COUNT(*) FILTER (WHERE processed_value = 0.0)
    INTO v_total, v_val_1, v_val_0
    FROM ma.indicator_values
    WHERE indicator_code = 'ENV_FOR'
      AND layer_id = 3;

    v_pct_extr := ROUND(((v_val_1 + v_val_0) * 100.0 / NULLIF(v_total, 0))::numeric, 1);

    RAISE NOTICE 'L3 ENV_FOR -- total: %, val=1.0: %, val=0.0: %, pct_extremes: %%',
        v_total, v_val_1, v_val_0, v_pct_extr;

    IF v_pct_extr > 30 THEN
        RAISE EXCEPTION
            'L3 ENV_FOR suspect : %% de valeurs extrêmes (0 ou 1). '
            'Vérifier que imputer_v3 a bien recalculé ENV_FOR avant de continuer.',
            v_pct_extr;
    END IF;
END $$;

-- ============================================================
-- ÉTAPE 2 — Recalcul computed_values WKN_PENV
-- Supprimer et recalculer depuis L3 via le script de calcul WKN
-- Note : le script de calcul WKN original est l3_weakness.sql
-- On supprime uniquement WKN_PENV pour forcer le recalcul
-- ============================================================

DELETE FROM ma.computed_values
WHERE indicator_code = 'WKN_PENV';

-- Recalcul WKN_PENV depuis L3
-- Formule : WKN = 1 - AVG(processed_value) sur indicateurs positifs PENV
-- Confiance = AVG(confidence_score) des indicateurs alimentés
WITH penv_l3 AS (
    SELECT
        iv.country_iso3,
        iv.year,
        AVG(iv.processed_value)                          AS moy_score,
        AVG(iv.confidence_score)                         AS moy_conf,
        COUNT(DISTINCT iv.indicator_code)                AS nb_ind,
        jsonb_build_object(
            'pilier',       'PENV',
            'nb_positifs',  COUNT(DISTINCT iv.indicator_code),
            'score_L3_moy', ROUND(AVG(iv.processed_value)::numeric, 4),
            'obs_reelles',  COUNT(*) FILTER (WHERE iv.value_status = 'OBSERVED'),
            'imputees',     COUNT(*) FILTER (WHERE iv.value_status = 'IMPUTED')
        )                                                AS components
    FROM ma.indicator_values iv
    JOIN rf.indicators i
        ON i.code = iv.indicator_code
       AND i.pillar_code = 'PENV'
       AND i.is_active = true
    WHERE iv.layer_id = 3
      AND iv.processed_value IS NOT NULL
    GROUP BY iv.country_iso3, iv.year
    HAVING COUNT(DISTINCT iv.indicator_code) >= 1
)
INSERT INTO ma.computed_values
    (indicator_code, country_iso3, year, value, confidence, nb_indicators, components)
SELECT
    'WKN_PENV',
    country_iso3,
    year::smallint,
    ROUND(GREATEST(0, LEAST(1, 1.0 - moy_score))::numeric, 6),
    ROUND(moy_conf::numeric, 3),
    nb_ind::smallint,
    components
FROM penv_l3;

GET DIAGNOSTICS v_wkn_inserted = ROW_COUNT;

DO $$
DECLARE v_wkn_inserted INT;
BEGIN
    SELECT COUNT(*) INTO v_wkn_inserted
    FROM ma.computed_values WHERE indicator_code = 'WKN_PENV';
    RAISE NOTICE 'WKN_PENV recalculé : % lignes insérées', v_wkn_inserted;
END $$;

-- ============================================================
-- ÉTAPE 3 — Recalcul STR_PENV
-- Supprimer les 24 cas MISSING + recalculer
-- Formule : STR = AVG(norm_pos) WHERE norm_pos > moy_perimetre + sigma
-- ============================================================

DELETE FROM ma.computed_values
WHERE indicator_code = 'STR_PENV';

-- Recalcul STR_PENV
-- Forces distinctives = indicateurs PENV dont le score dépasse
-- la moyenne du périmètre + 1 écart-type (seuil de distinctivité)
WITH penv_stats AS (
    -- Calculer moy + sigma par année (périmètre 54 pays)
    SELECT
        year,
        AVG(processed_value)    AS moy_perimetre,
        STDDEV(processed_value) AS sigma_perimetre
    FROM ma.indicator_values iv
    JOIN rf.indicators i ON i.code = iv.indicator_code
       AND i.pillar_code = 'PENV' AND i.is_active = true
    WHERE iv.layer_id = 3
      AND iv.processed_value IS NOT NULL
    GROUP BY year
),
penv_forces AS (
    -- Pour chaque pays/année : indicateurs qui dépassent moy+sigma
    SELECT
        iv.country_iso3,
        iv.year,
        iv.indicator_code,
        iv.processed_value,
        iv.confidence_score,
        ps.moy_perimetre,
        ps.sigma_perimetre
    FROM ma.indicator_values iv
    JOIN rf.indicators i ON i.code = iv.indicator_code
       AND i.pillar_code = 'PENV' AND i.is_active = true
    JOIN penv_stats ps ON ps.year = iv.year
    WHERE iv.layer_id = 3
      AND iv.processed_value IS NOT NULL
      AND iv.processed_value > (ps.moy_perimetre + ps.sigma_perimetre)
),
str_aggregated AS (
    SELECT
        country_iso3,
        year,
        AVG(processed_value)      AS str_score,
        -- Règle de garde : confidence = 0 si unique force avec
        -- confidence_score = 0 (donnée source non fiable)
        CASE
            WHEN COUNT(*) = 1 AND MIN(confidence_score) = 0 THEN 0.000
            ELSE ROUND(AVG(confidence_score)::numeric, 3)
        END                       AS str_confidence,
        COUNT(*)::smallint        AS nb_forces,
        jsonb_build_object(
            'pilier',     'PENV',
            'nb_forces',  COUNT(*),
            'moy_seuil',  ROUND(AVG(moy_perimetre + sigma_perimetre)::numeric, 4)
        )                         AS components
    FROM penv_forces
    GROUP BY country_iso3, year
)
INSERT INTO ma.computed_values
    (indicator_code, country_iso3, year, value, confidence, nb_indicators, components)
SELECT
    'STR_PENV',
    country_iso3,
    year::smallint,
    ROUND(GREATEST(0, LEAST(1, str_score))::numeric, 6),
    str_confidence,
    nb_forces,
    components
FROM str_aggregated;

DO $$
DECLARE
    v_str_total   INT;
    v_str_missing INT;
BEGIN
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE data_availability = 'MISSING')
    INTO v_str_total, v_str_missing
    FROM ma.computed_values
    WHERE indicator_code = 'STR_PENV';
    RAISE NOTICE 'STR_PENV recalculé : % lignes, % MISSING (attendu : 0 si ENV_FOR corrigé)',
        v_str_total, v_str_missing;
END $$;

-- ============================================================
-- ÉTAPE 4 — Recalcul compute_pillar_score PENV 2020-2024
-- Mettre à jour les scores pilier officiels
-- ============================================================

DO $$
DECLARE
    v_year  INT;
    v_rows  INT;
    v_total INT := 0;
BEGIN
    FOR v_year IN 2020..2024 LOOP
        SELECT ma.compute_pillar_score('PENV', v_year) INTO v_rows;
        v_total := v_total + v_rows;
        RAISE NOTICE 'compute_pillar_score PENV % : % pays recalculés', v_year, v_rows;
    END LOOP;
    RAISE NOTICE 'PENV pillar scores recalculés : % lignes au total', v_total;
END $$;

-- ============================================================
-- ÉTAPE 5 — Mise à jour data_availability sur computed_values
-- Les nouvelles lignes WKN_PENV et STR_PENV n'ont pas
-- data_availability renseigné (colonne ajoutée Sprint 26 Lot A)
-- ============================================================

UPDATE ma.computed_values
SET data_availability = CASE
    WHEN value IS NULL OR confidence = 0               THEN 'MISSING'
    WHEN confidence > 0 AND confidence < 0.90          THEN 'ESTIMATED'
    ELSE                                                    'OBSERVED'
END
WHERE indicator_code IN ('WKN_PENV', 'STR_PENV')
  AND data_availability IS NULL;

-- ============================================================
-- ÉTAPE 6 — VÉRIFICATIONS FINALES
-- ============================================================

-- 6.1 WKN_PENV — vérifier que SDN 2024 a une valeur maintenant
SELECT
    indicator_code,
    country_iso3,
    year,
    value,
    confidence,
    data_availability
FROM ma.computed_values
WHERE indicator_code = 'WKN_PENV'
  AND country_iso3 = 'SDN'
  AND year = 2024;

-- 6.2 STR_PENV — distribution data_availability après correction
SELECT
    data_availability,
    COUNT(*) AS nb
FROM ma.computed_values
WHERE indicator_code = 'STR_PENV'
GROUP BY data_availability
ORDER BY data_availability;

-- 6.3 Vue audit — CRITICAL_GAP et MONITORING restants
SELECT
    alert_level,
    COUNT(*) AS nb
FROM ops.v_data_availability_audit
GROUP BY alert_level
ORDER BY alert_level;

-- 6.4 Résumé WKN_MISSING après correction
SELECT *
FROM ops.v_wkn_missing_summary
ORDER BY year DESC, country_iso3;

-- ============================================================
-- ÉTAPE 7 — Clôture finding #28 si vérifications OK
-- À exécuter manuellement après validation des résultats ci-dessus
-- ============================================================

-- UPDATE ops.audit_findings
-- SET
--     status    = 'RESOLVED',
--     closed_at = NOW(),
--     updated_at = NOW(),
--     raw_finding = raw_finding || '{
--       "resolution": {
--         "resolved_at": "2026-06-23",
--         "patch_applied": "sprint26_lot_c_env_for.sql",
--         "pipeline_rerun": "imputer_v3 + compute_pillar_score PENV 2020-2024",
--         "str_penv_missing_before": 24,
--         "str_penv_missing_after": 0
--       }
--     }''::jsonb
-- WHERE finding_id = 28
--   AND finding_code = ''ENV_FOR_CORRECTION_PENDING'';

COMMIT;
