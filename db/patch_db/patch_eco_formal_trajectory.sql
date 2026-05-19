-- ============================================================
-- OSA Observatory — patch_eco_formal_trajectory.sql
-- Sprint 7 — Mai 2026
--
-- Indicateur calculé L3 : ECO_FORMAL_TRAJECTORY
-- Trajectoire de formalisation économique (variation 2 ans glissants)
--
-- Formule :
--   taux_formal(i, t)  = 100 - ECO_INFORMAL_RATE(i, t)   [layer_id=3]
--   trajectory(i, t)   = AVG(
--       taux_formal(i,t)   - taux_formal(i,t-1),
--       taux_formal(i,t-1) - taux_formal(i,t-2)
--   )
--
-- Interprétation :
--   > 0  : formalisation active — gain de souveraineté économique
--   = 0  : stagnation
--   < 0  : dé-formalisation — recul de la souveraineté
--
-- Disponible à partir de 2012 (fenêtre t, t-1, t-2 requise)
-- NULL pour 2010 et 2011.
--
-- Source : ECO_INFORMAL_RATE (ILOSTAT SDG 8.3.1)
-- Pilier  : PECO
-- Layer   : directement en L3 (pas de L1/L2 pour les COMPUTED)
--
-- Prérequis :
--   ECO_INFORMAL_RATE doit être en L3 (layer_id=3)
--   rf.indicators.code = 'ECO_INFORMAL_RATE' existant
--
-- Idempotent — peut être rejoué.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Enregistrement dans rf.indicators
-- ------------------------------------------------------------

INSERT INTO rf.indicators (
    code,
    name_fr,
    name_en,
    pillar_code,
    unit_code,
    direction,
    description,
    display_order,
    is_active,
    imputation_regime,
    is_composite_score,
    has_structural_zeros
)
VALUES (
    'ECO_FORMAL_TRAJECTORY',
    'Trajectoire de formalisation économique (variation 2 ans glissants)',
    'Economic formalization trajectory (2-year rolling average change)',
    'PECO',
    'PCT',
    '+',
    'Variation moyenne sur 2 ans glissants du taux de formalisation économique '
    '(= 100 − ECO_INFORMAL_RATE). '
    'Une valeur positive indique une progression de la formalisation — '
    'gain de souveraineté économique mesurable. '
    'Une valeur négative indique une dé-formalisation. '
    'Indicateur COMPUTED dérivé de ECO_INFORMAL_RATE (ILOSTAT SDG 8.3.1). '
    'Disponible à partir de 2012. NULL pour 2010–2011. '
    'Note : l''informalité en Afrique n''est pas intrinsèquement négative — '
    'cet indicateur mesure la trajectoire de changement, pas le niveau absolu.',
    23,
    TRUE,
    'COMPUTED',
    FALSE,
    FALSE
)
ON CONFLICT (code) DO UPDATE SET
    name_fr           = EXCLUDED.name_fr,
    name_en           = EXCLUDED.name_en,
    description       = EXCLUDED.description,
    direction         = EXCLUDED.direction,
    imputation_regime = EXCLUDED.imputation_regime,
    is_active         = EXCLUDED.is_active;

-- ------------------------------------------------------------
-- 2. Calcul et insertion L3
--    Source : ECO_INFORMAL_RATE layer_id=3 (valeur normalisée)
--    On travaille sur raw_value (valeur brute %) pour le calcul
--    de trajectoire, puis on normalise le résultat.
-- ------------------------------------------------------------

WITH
-- Source : valeurs brutes L3 de ECO_INFORMAL_RATE
-- On prend raw_value (% informel brut) pour le calcul de trajectoire
informal AS (
    SELECT DISTINCT ON (country_iso3, year)
        country_iso3,
        year,
        raw_value::numeric          AS informal_rate,
        confidence_score::numeric   AS conf,
        source_id,
        method_version_id
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_INFORMAL_RATE'
      AND layer_id       = 3
      AND raw_value      IS NOT NULL
    ORDER BY country_iso3, year, id DESC  -- prend la ligne la plus récente si doublon
),

-- Taux de formalisation
formal AS (
    SELECT
        country_iso3,
        year,
        (100.0 - informal_rate)     AS formal_rate,
        conf,
        source_id,
        method_version_id
    FROM informal
),

-- Variation 2 ans glissants
trajectory AS (
    SELECT
        country_iso3,
        year,
        -- Delta t vs t-1
        (formal_rate - LAG(formal_rate, 1) OVER w)  AS delta_1,
        -- Delta t-1 vs t-2
        (LAG(formal_rate, 1) OVER w - LAG(formal_rate, 2) OVER w) AS delta_2,
        conf,
        source_id,
        method_version_id
    FROM formal
    WINDOW w AS (PARTITION BY country_iso3 ORDER BY year)
),

-- Moyenne des deux deltas — NULL si l'une des deux est NULL (2010, 2011)
computed AS (
    SELECT
        country_iso3,
        year,
        CASE
            WHEN delta_1 IS NOT NULL AND delta_2 IS NOT NULL
            THEN ROUND((delta_1 + delta_2) / 2.0, 6)
            ELSE NULL
        END AS trajectory_value,
        LEAST(1.000, GREATEST(0.000, COALESCE(conf, 0.700))) AS confidence,
        source_id,
        method_version_id
    FROM trajectory
    WHERE delta_1 IS NOT NULL AND delta_2 IS NOT NULL
)

-- Insertion L3 directe (COMPUTED — pas de L1/L2)
INSERT INTO ma.indicator_values (
    indicator_code,
    country_iso3,
    year,
    layer_id,
    raw_value,
    processed_value,
    confidence_score,
    source_id,
    method_version_id,
    is_estimated,
    quality_flag,
    value_status
)
SELECT
    'ECO_FORMAL_TRAJECTORY',
    country_iso3,
    year,
    3,                          -- directement en L3
    trajectory_value,           -- raw_value = valeur calculée (points de %)
    trajectory_value,           -- processed_value = idem (pas de normalisation min-max)
    confidence,
    source_id,
    method_version_id,
    FALSE,
    'ESTIMATED',
    'IMPUTED'
FROM computed
WHERE trajectory_value IS NOT NULL
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 3. Vérification
-- ------------------------------------------------------------

DO $$
DECLARE
    v_count    INTEGER;
    v_pays     INTEGER;
    v_min_year INTEGER;
    v_max_year INTEGER;
    v_pos      INTEGER;
    v_neg      INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT country_iso3),
           MIN(year), MAX(year),
           SUM(CASE WHEN raw_value > 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN raw_value < 0 THEN 1 ELSE 0 END)
    INTO v_count, v_pays, v_min_year, v_max_year, v_pos, v_neg
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_FORMAL_TRAJECTORY'
      AND layer_id = 3;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'ECO_FORMAL_TRAJECTORY — CALCULÉ';
    RAISE NOTICE '  Lignes insérées : %',    v_count;
    RAISE NOTICE '  Pays couverts   : %/54', v_pays;
    RAISE NOTICE '  Années          : % → %', v_min_year, v_max_year;
    RAISE NOTICE '  Formalisation + : % cas', v_pos;
    RAISE NOTICE '  Dé-formalisation: % cas', v_neg;
    RAISE NOTICE '  (NULL pour 2010 et 2011 — fenêtre glissante)';
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
