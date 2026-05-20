-- ============================================================
-- OSA Observatory — patch_eco_public_leakage_l3.sql
-- Sprint 8 — Mai 2026
--
-- Indicateur COMPUTED L3 : ECO_PUBLIC_LEAKAGE
-- Pilier : PECO — Souveraineté économique
-- Direction : − (écart élevé = fuite = souveraineté affaiblie)
--
-- Formule :
--   ECO_PUBLIC_LEAKAGE = normalize(ECO_PUBLIC_REV) − normalize(ECO_TAX)
--   → écart entre recettes publiques totales et recettes fiscales normalisées
--   → Écart élevé = forte dépendance aux dons/ressources non fiscales
--   → Écart faible = mobilisation fiscale efficace
--
-- Sources (layer_id=3) :
--   ECO_PUBLIC_REV (GC.REV.XGRT.GD.ZS) : 54/54 pays — 3150 lignes
--   ECO_TAX        (GC.TAX.TOTL.GD.ZS)  : 54/54 pays — 2079 lignes
--
-- Indicateur dérivé également calculé :
--   ECO_TAX_EFFICIENCY = ECO_TAX / ECO_PUBLIC_REV
--   → ratio d'efficacité fiscale (proportion des recettes venant de la fiscalité)
--
-- Note doctrinale :
--   Fait observable : données gouvernementales officielles WB/FMI.
--   Mesure l'écart de performance, pas la malversation.
--   Conforme doctrine OSA d'observation comportementale.
--   Publication : "Public Revenue Efficiency Index" — éviter "leakage"
--   dans les communications institutionnelles.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Enregistrement rf.indicators — ECO_PUBLIC_LEAKAGE
-- ------------------------------------------------------------

INSERT INTO rf.indicators (
    code, name_fr, name_en, pillar_code, unit_code, direction,
    description, display_order, is_active, imputation_regime,
    is_composite_score, has_structural_zeros
)
VALUES (
    'ECO_PUBLIC_LEAKAGE',
    'Fuite des finances publiques — sous-mobilisation des recettes fiscales',
    'Public Finance Leakage — Tax Revenue Under-mobilisation',
    'PECO', 'SCORE_NORM', '-',
    'Écart normalisé entre les recettes publiques totales hors dons (ECO_PUBLIC_REV) '
    'et les recettes fiscales (ECO_TAX). '
    'Un écart élevé indique une forte dépendance aux recettes non fiscales '
    '(ressources naturelles, dons) et une sous-mobilisation fiscale. '
    'Sources : GC.REV.XGRT.GD.ZS + GC.TAX.TOTL.GD.ZS (World Bank WDI). '
    'Couverture : 54 pays africains 2010–2024. '
    'Doctrine OSA : fait observable — données gouvernementales officielles. '
    'Mesure l''écart de performance, pas la malversation. '
    'Publication : libellé Public Revenue Efficiency Index. '
    'Methodology note API obligatoire.',
    25, TRUE, 'COMPUTED', FALSE, FALSE
)
ON CONFLICT (code) DO UPDATE SET
    name_fr = EXCLUDED.name_fr, name_en = EXCLUDED.name_en,
    description = EXCLUDED.description, is_active = EXCLUDED.is_active;

-- ------------------------------------------------------------
-- 2. Enregistrement rf.indicators — ECO_TAX_EFFICIENCY
-- ------------------------------------------------------------

INSERT INTO rf.indicators (
    code, name_fr, name_en, pillar_code, unit_code, direction,
    description, display_order, is_active, imputation_regime,
    is_composite_score, has_structural_zeros
)
VALUES (
    'ECO_TAX_EFFICIENCY',
    'Efficacité de mobilisation fiscale (recettes fiscales / recettes totales)',
    'Tax Mobilisation Efficiency (tax revenue / total revenue)',
    'PECO', 'SCORE_NORM', '+',
    'Ratio normalisé entre les recettes fiscales (ECO_TAX) et les recettes '
    'publiques totales hors dons (ECO_PUBLIC_REV). '
    'Un ratio élevé indique une mobilisation fiscale efficace. '
    'Complémentaire de ECO_PUBLIC_LEAKAGE.',
    26, TRUE, 'COMPUTED', FALSE, FALSE
)
ON CONFLICT (code) DO UPDATE SET
    name_fr = EXCLUDED.name_fr, name_en = EXCLUDED.name_en,
    description = EXCLUDED.description, is_active = EXCLUDED.is_active;

-- ------------------------------------------------------------
-- 3. Calcul L3 — ECO_PUBLIC_LEAKAGE
-- ------------------------------------------------------------

INSERT INTO ma.indicator_values (
    indicator_code, country_iso3, year, layer_id,
    raw_value, processed_value,
    confidence_score, is_estimated, quality_flag, value_status
)
WITH rev AS (
    SELECT country_iso3, year,
           processed_value AS rev_norm,
           confidence_score AS conf_rev
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_PUBLIC_REV'
      AND layer_id = 3 AND processed_value IS NOT NULL
),
tax AS (
    SELECT country_iso3, year,
           processed_value AS tax_norm,
           confidence_score AS conf_tax
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_TAX'
      AND layer_id = 3 AND processed_value IS NOT NULL
),
computed AS (
    SELECT
        r.country_iso3, r.year,
        r.rev_norm - t.tax_norm                                     AS leakage_raw,
        LEAST(1.0, GREATEST(0.0,
            (r.rev_norm - t.tax_norm + 1.0) / 2.0
        ))                                                           AS leakage_norm,
        LEAST(
            COALESCE(r.conf_rev, 0.700),
            COALESCE(t.conf_tax, 0.700)
        )                                                            AS confidence
    FROM rev r
    JOIN tax t ON t.country_iso3 = r.country_iso3 AND t.year = r.year
)
SELECT
    'ECO_PUBLIC_LEAKAGE', country_iso3, year, 3,
    leakage_raw, leakage_norm,
    confidence, FALSE, 'ESTIMATED', 'IMPUTED'
FROM computed WHERE leakage_raw IS NOT NULL
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 4. Calcul L3 — ECO_TAX_EFFICIENCY
-- ------------------------------------------------------------

INSERT INTO ma.indicator_values (
    indicator_code, country_iso3, year, layer_id,
    raw_value, processed_value,
    confidence_score, is_estimated, quality_flag, value_status
)
WITH rev AS (
    SELECT country_iso3, year, processed_value AS rev_norm,
           confidence_score AS conf_rev
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_PUBLIC_REV'
      AND layer_id = 3 AND processed_value IS NOT NULL AND processed_value > 0
),
tax AS (
    SELECT country_iso3, year, processed_value AS tax_norm,
           confidence_score AS conf_tax
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_TAX'
      AND layer_id = 3 AND processed_value IS NOT NULL
),
computed AS (
    SELECT
        r.country_iso3, r.year,
        t.tax_norm / r.rev_norm                                      AS efficiency_raw,
        LEAST(1.0, GREATEST(0.0, t.tax_norm / r.rev_norm))          AS efficiency_norm,
        LEAST(
            COALESCE(r.conf_rev, 0.700),
            COALESCE(t.conf_tax, 0.700)
        )                                                            AS confidence
    FROM rev r
    JOIN tax t ON t.country_iso3 = r.country_iso3 AND t.year = r.year
)
SELECT
    'ECO_TAX_EFFICIENCY', country_iso3, year, 3,
    efficiency_raw, efficiency_norm,
    confidence, FALSE, 'ESTIMATED', 'IMPUTED'
FROM computed WHERE efficiency_raw IS NOT NULL
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 5. Vérification
-- ------------------------------------------------------------

DO $$
DECLARE
    v_leak_nb   INTEGER; v_leak_pays INTEGER;
    v_leak_min  NUMERIC; v_leak_max  NUMERIC; v_leak_avg NUMERIC;
    v_leak_pos  INTEGER; v_leak_neg  INTEGER;
    v_eff_nb    INTEGER; v_eff_pays  INTEGER;
    v_eff_avg   NUMERIC;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT country_iso3),
           ROUND(MIN(raw_value)::numeric,3), ROUND(MAX(raw_value)::numeric,3),
           ROUND(AVG(raw_value)::numeric,3)
    INTO v_leak_nb, v_leak_pays, v_leak_min, v_leak_max, v_leak_avg
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_PUBLIC_LEAKAGE' AND layer_id = 3;

    SELECT COUNT(*) INTO v_leak_pos FROM ma.indicator_values
    WHERE indicator_code = 'ECO_PUBLIC_LEAKAGE' AND layer_id = 3 AND raw_value > 0;

    SELECT COUNT(*) INTO v_leak_neg FROM ma.indicator_values
    WHERE indicator_code = 'ECO_PUBLIC_LEAKAGE' AND layer_id = 3 AND raw_value <= 0;

    SELECT COUNT(*), COUNT(DISTINCT country_iso3), ROUND(AVG(raw_value)::numeric,3)
    INTO v_eff_nb, v_eff_pays, v_eff_avg
    FROM ma.indicator_values
    WHERE indicator_code = 'ECO_TAX_EFFICIENCY' AND layer_id = 3;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'ECO_PUBLIC_LEAKAGE — COMPUTED L3';
    RAISE NOTICE '  Lignes       : %', v_leak_nb;
    RAISE NOTICE '  Pays         : %/54', v_leak_pays;
    RAISE NOTICE '  Écart min    : %', v_leak_min;
    RAISE NOTICE '  Écart max    : %', v_leak_max;
    RAISE NOTICE '  Écart moyen  : %', v_leak_avg;
    RAISE NOTICE '  Fuite (>0)   : % cas', v_leak_pos;
    RAISE NOTICE '  Sain  (<=0)  : % cas', v_leak_neg;
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'ECO_TAX_EFFICIENCY — COMPUTED L3';
    RAISE NOTICE '  Lignes       : %', v_eff_nb;
    RAISE NOTICE '  Pays         : %/54', v_eff_pays;
    RAISE NOTICE '  Ratio moyen  : % (part fiscale dans recettes totales)', v_eff_avg;
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
