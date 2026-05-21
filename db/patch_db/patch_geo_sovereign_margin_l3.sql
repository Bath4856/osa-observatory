-- ============================================================
-- OSA Observatory — patch_geo_sovereign_margin_l3.sql
-- Sprint 8 — Mai 2026
--
-- Indicateur COMPUTED L3 : GEO_SOVEREIGN_MARGIN
-- Pilier : PGEO — Souveraineté géopolitique
-- Direction : + (marge élevée = potentiel souverain mobilisable = bon)
--
-- Formule :
--   GEO_SOVEREIGN_MARGIN = 1 − normalize(ECO_PUBLIC_LEAKAGE)
--   → inverse de l'écart fiscal normalisé
--   → score élevé = grande marge de mobilisation fiscale non exploitée
--
-- Doctrine OSA (v1) :
--   Remplace GEO_CAPTURE_RISK (mesure de défaillance — rejeté).
--   GEO_SOVEREIGN_MARGIN mesure une opportunité, pas une défaillance.
--   Un État avec un score élevé dispose d'un levier souverain mobilisable
--   pour réduire sa dépendance aux recettes extractives et aux dons.
--
--   Usage interne   : identifier le levier fiscal à mobiliser
--   Usage régional  : coopération UA sur la mobilisation fiscale
--   Usage diplomatique : négocier depuis une base souveraine vérifiable
--
--   Publication : "Fiscal Sovereign Margin — Mobilisable Revenue Gap"
--   Jamais qualifié de "capture institutionnelle" ou "corruption".
--
-- Source : ECO_PUBLIC_LEAKAGE (layer_id=3, 13 473 lignes, 54/54 pays)
-- Couverture : 54 pays africains 2010–2024
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Enregistrement rf.indicators — GEO_SOVEREIGN_MARGIN
-- ------------------------------------------------------------

INSERT INTO rf.indicators (
    code, name_fr, name_en, pillar_code, unit_code, direction,
    description, display_order, is_active, imputation_regime,
    is_composite_score, has_structural_zeros
)
VALUES (
    'GEO_SOVEREIGN_MARGIN',
    'Marge de souveraineté fiscale mobilisable',
    'Fiscal Sovereign Margin — Mobilisable Revenue Gap',
    'PGEO', 'SCORE_NORM', '+',
    'Mesure la marge de mobilisation fiscale non encore exploitée par un État. '
    'Calculé comme l''inverse de ECO_PUBLIC_LEAKAGE — l''écart entre recettes '
    'publiques totales et recettes fiscales normalisé. '
    'Un score élevé indique qu''un État dispose d''un potentiel souverain '
    'mobilisable pour réduire sa dépendance aux recettes non fiscales '
    '(ressources naturelles, dons, aide externe). '
    'DOCTRINE OSA v1 : remplace GEO_CAPTURE_RISK (mesure de défaillance rejetée). '
    'GEO_SOVEREIGN_MARGIN est un signal d''opportunité, pas de défaillance. '
    'Usage : priorisation interne des réformes fiscales + diplomatie UA. '
    'Publication : libellé Fiscal Sovereign Margin — jamais qualifié de '
    'capture institutionnelle ou de corruption sans preuve juridique indépendante.',
    31, TRUE, 'COMPUTED', FALSE, FALSE
)
ON CONFLICT (code) DO UPDATE SET
    name_fr     = EXCLUDED.name_fr,
    name_en     = EXCLUDED.name_en,
    description = EXCLUDED.description,
    direction   = EXCLUDED.direction,
    is_active   = EXCLUDED.is_active;

-- ------------------------------------------------------------
-- 2. Calcul L3 — GEO_SOVEREIGN_MARGIN = 1 − ECO_PUBLIC_LEAKAGE
-- ------------------------------------------------------------

INSERT INTO ma.indicator_values (
    indicator_code, country_iso3, year, layer_id,
    raw_value, processed_value,
    confidence_score, is_estimated, quality_flag, value_status
)
SELECT
    'GEO_SOVEREIGN_MARGIN',
    country_iso3,
    year,
    3,
    -- raw_value : marge brute = 1 − écart normalisé (entre 0 et 1)
    LEAST(1.0, GREATEST(0.0, 1.0 - processed_value))        AS raw_value,
    -- processed_value = idem (déjà normalisé 0-1 par construction)
    LEAST(1.0, GREATEST(0.0, 1.0 - processed_value))        AS processed_value,
    confidence_score,
    FALSE,
    'ESTIMATED',
    'IMPUTED'
FROM ma.indicator_values
WHERE indicator_code = 'ECO_PUBLIC_LEAKAGE'
  AND layer_id = 3
  AND processed_value IS NOT NULL
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 3. Vérification
-- ------------------------------------------------------------

DO $$
DECLARE
    v_nb      INTEGER;
    v_pays    INTEGER;
    v_min     NUMERIC;
    v_max     NUMERIC;
    v_avg     NUMERIC;
    v_high    INTEGER;  -- marge élevée > 0.5 = potentiel souverain fort
    v_low     INTEGER;  -- marge faible <= 0.5 = mobilisation fiscale déjà avancée
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT country_iso3),
           ROUND(MIN(processed_value)::numeric, 3),
           ROUND(MAX(processed_value)::numeric, 3),
           ROUND(AVG(processed_value)::numeric, 3)
    INTO v_nb, v_pays, v_min, v_max, v_avg
    FROM ma.indicator_values
    WHERE indicator_code = 'GEO_SOVEREIGN_MARGIN' AND layer_id = 3;

    SELECT COUNT(*) INTO v_high
    FROM ma.indicator_values
    WHERE indicator_code = 'GEO_SOVEREIGN_MARGIN'
      AND layer_id = 3 AND processed_value > 0.5;

    SELECT COUNT(*) INTO v_low
    FROM ma.indicator_values
    WHERE indicator_code = 'GEO_SOVEREIGN_MARGIN'
      AND layer_id = 3 AND processed_value <= 0.5;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'GEO_SOVEREIGN_MARGIN — COMPUTED L3';
    RAISE NOTICE '  Doctrine OSA v1 — remplace GEO_CAPTURE_RISK';
    RAISE NOTICE '  Lignes insérées  : %', v_nb;
    RAISE NOTICE '  Pays couverts    : %/54', v_pays;
    RAISE NOTICE '  Années           : 2010 → 2024';
    RAISE NOTICE '  Score min        : % (mobilisation fiscale avancée)', v_min;
    RAISE NOTICE '  Score max        : % (grand potentiel souverain)', v_max;
    RAISE NOTICE '  Score moyen      : %', v_avg;
    RAISE NOTICE '  Potentiel fort   : % cas (score > 0.5)', v_high;
    RAISE NOTICE '  Mobilisation av. : % cas (score <= 0.5)', v_low;
    RAISE NOTICE '============================================';

    -- Top 5 pays 2024 avec le plus grand potentiel souverain
    RAISE NOTICE 'Top 5 pays avec le plus grand potentiel souverain (2024) :';
END;
$$;

-- Top 5 pays 2024
SELECT country_iso3,
       ROUND(processed_value::numeric, 3) AS marge_souveraine,
       ROUND(confidence_score::numeric, 3) AS confidence
FROM ma.indicator_values
WHERE indicator_code = 'GEO_SOVEREIGN_MARGIN'
  AND layer_id = 3 AND year = 2024
ORDER BY processed_value DESC
LIMIT 5;

COMMIT;
