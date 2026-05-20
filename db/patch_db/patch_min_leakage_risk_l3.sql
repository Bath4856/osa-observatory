-- ============================================================
-- OSA Observatory — patch_min_leakage_risk_l3.sql
-- Sprint 8 — Mai 2026
--
-- Indicateur COMPUTED L3 : MIN_LEAKAGE_RISK
-- Pilier : PMIN — Souveraineté minière
-- Direction : − (écart élevé = fuite = souveraineté affaiblie)
--
-- Formule :
--   MIN_LEAKAGE_RISK = normalize(PRES_FOSSIL_RENTS_EIA) − normalize(MIN_GOV)
--   → écart entre rente fossile normalisée et gouvernance déclarée normalisée
--   → valeur positive = rente > gouvernance déclarée → risque de fuite
--   → valeur négative = gouvernance couvre la rente → situation saine
--
-- Sources (layer_id=3) :
--   PRES_FOSSIL_RENTS_EIA : 54/54 pays — source EIA
--   MIN_GOV               : 54/54 pays — source EITI (810 lignes)
--
-- Couverture :
--   54 pays × 15 ans (2010–2024) = 810 lignes max
--   NULL si l'une des deux sources est absente pour un pays/année
--
-- Note doctrinale :
--   Fait comptable : écart entre rente théorique (EIA) et
--   recettes déclarées vérifiées (EITI). Double vérification
--   indépendante. Conforme doctrine OSA d'observation comportementale.
--   Publication : "Extractive Revenue Leakage Risk" — signal analytique,
--   pas accusation. Methodology note API obligatoire.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Enregistrement dans rf.indicators
-- ------------------------------------------------------------

INSERT INTO rf.indicators (
    code, name_fr, name_en, pillar_code, unit_code, direction,
    description, display_order, is_active, imputation_regime,
    is_composite_score, has_structural_zeros
)
VALUES (
    'MIN_LEAKAGE_RISK',
    'Risque de fuite des recettes extractives (écart rente-gouvernance normalisé)',
    'Extractive Revenue Leakage Risk (normalized rent-governance gap)',
    'PMIN', 'SCORE_NORM', '-',
    'Écart normalisé entre la rente fossile (PRES_FOSSIL_RENTS_EIA, source EIA) '
    'et la gouvernance des recettes extractives déclarées (MIN_GOV, source EITI). '
    'Valeur positive = rente > gouvernance déclarée = risque de fuite souveraine. '
    'Valeur négative = gouvernance couvre la rente = situation saine. '
    'Couverture : 54 pays africains 2010–2024. '
    'Note : MIN_GOV couvre 28 pays membres EITI directement ; '
    'les 26 autres sont imputés par MICE depuis les données EITI disponibles. '
    'Doctrine OSA : fait comptable observable — double vérification indépendante EIA/EITI. '
    'Publication : libellé Extractive Revenue Leakage Risk — '
    'signal analytique, pas accusation. Methodology note API obligatoire.',
    28, TRUE, 'COMPUTED', FALSE, FALSE
)
ON CONFLICT (code) DO UPDATE SET
    name_fr           = EXCLUDED.name_fr,
    name_en           = EXCLUDED.name_en,
    description       = EXCLUDED.description,
    direction         = EXCLUDED.direction,
    imputation_regime = EXCLUDED.imputation_regime,
    is_active         = EXCLUDED.is_active;

-- ------------------------------------------------------------
-- 2. Calcul L3 — INSERT direct
-- ------------------------------------------------------------

INSERT INTO ma.indicator_values (
    indicator_code, country_iso3, year, layer_id,
    raw_value, processed_value,
    confidence_score, is_estimated,
    quality_flag, value_status
)
WITH rente AS (
    SELECT country_iso3, year,
           processed_value AS rente_norm,
           confidence_score AS conf_rente
    FROM ma.indicator_values
    WHERE indicator_code = 'PRES_FOSSIL_RENTS_EIA'
      AND layer_id = 3
      AND processed_value IS NOT NULL
),
gouv AS (
    SELECT country_iso3, year,
           processed_value AS gouv_norm,
           confidence_score AS conf_gouv
    FROM ma.indicator_values
    WHERE indicator_code = 'MIN_GOV'
      AND layer_id = 3
      AND processed_value IS NOT NULL
),
computed AS (
    SELECT
        r.country_iso3,
        r.year,
        -- raw_value = écart brut (peut être négatif)
        r.rente_norm - g.gouv_norm                                  AS leakage_value,
        -- processed_value = écart borné entre -1 et 1 → ramené 0-1
        -- 0.5 = équilibre, > 0.5 = fuite, < 0.5 = sain
        LEAST(1.0, GREATEST(0.0,
            (r.rente_norm - g.gouv_norm + 1.0) / 2.0
        ))                                                           AS leakage_norm,
        -- confidence = min des deux sources
        LEAST(
            COALESCE(r.conf_rente, 0.700),
            COALESCE(g.conf_gouv,  0.700)
        )                                                            AS confidence
    FROM rente r
    JOIN gouv  g ON g.country_iso3 = r.country_iso3
                AND g.year         = r.year
)
SELECT
    'MIN_LEAKAGE_RISK',
    country_iso3,
    year,
    3,                  -- layer_id = L3
    leakage_value,      -- raw_value = écart brut
    leakage_norm,       -- processed_value = score normalisé 0-1
    confidence,
    FALSE,              -- is_estimated
    'ESTIMATED',        -- quality_flag
    'IMPUTED'           -- value_status (COMPUTED)
FROM computed
WHERE leakage_value IS NOT NULL
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 3. Vérification
-- ------------------------------------------------------------

DO $$
DECLARE
    v_nb    INTEGER;
    v_pays  INTEGER;
    v_min   NUMERIC;
    v_max   NUMERIC;
    v_avg   NUMERIC;
    v_pos   INTEGER;  -- cas de fuite (écart > 0)
    v_neg   INTEGER;  -- cas sains (écart <= 0)
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT country_iso3),
           ROUND(MIN(raw_value)::numeric, 3),
           ROUND(MAX(raw_value)::numeric, 3),
           ROUND(AVG(raw_value)::numeric, 3)
    INTO v_nb, v_pays, v_min, v_max, v_avg
    FROM ma.indicator_values
    WHERE indicator_code = 'MIN_LEAKAGE_RISK' AND layer_id = 3;

    SELECT COUNT(*) INTO v_pos
    FROM ma.indicator_values
    WHERE indicator_code = 'MIN_LEAKAGE_RISK'
      AND layer_id = 3 AND raw_value > 0;

    SELECT COUNT(*) INTO v_neg
    FROM ma.indicator_values
    WHERE indicator_code = 'MIN_LEAKAGE_RISK'
      AND layer_id = 3 AND raw_value <= 0;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'MIN_LEAKAGE_RISK — COMPUTED L3';
    RAISE NOTICE '  Lignes insérées   : %', v_nb;
    RAISE NOTICE '  Pays couverts     : %/54', v_pays;
    RAISE NOTICE '  Années            : 2010 → 2024';
    RAISE NOTICE '  Écart brut min    : %', v_min;
    RAISE NOTICE '  Écart brut max    : %', v_max;
    RAISE NOTICE '  Écart brut moyen  : %', v_avg;
    RAISE NOTICE '  Cas fuite (>0)    : %', v_pos;
    RAISE NOTICE '  Cas sains (<=0)   : %', v_neg;
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
