-- ============================================================
-- OSA Observatory — patch_sprint8_new_indicators.sql
-- Sprint 8 — Mai 2026
--
-- Enregistrement des nouveaux indicateurs Sprint 8 :
--   MON_GDP_CURRENT  — PIB courant USD auxiliaire (PMON)
--   ECO_PUBLIC_REV   — Recettes publiques hors dons % PIB (PECO)
--
-- Note : MON_IFF_PRESSURE est déjà enregistré via
--        patch_mon_iff_pressure_registration.sql
--
-- Dépendances vérifiées :
--   WB provider (id=1) et WB_COUNTRY_INDICATOR endpoint (id=1)
--   collect.source_registry WB_BOP (id=36) — existant
--   collect.source_registry WB (id=11) — existant (générique)
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. rf.indicators — MON_GDP_CURRENT (auxiliaire PIB)
-- ------------------------------------------------------------

INSERT INTO rf.indicators (
    code, name_fr, name_en, pillar_code, unit_code, direction,
    description, display_order, is_active, imputation_regime,
    is_composite_score, has_structural_zeros
)
VALUES (
    'MON_GDP_CURRENT',
    'PIB courant (USD millions) — auxiliaire conversion BoP',
    'Current GDP (USD millions) — BoP conversion auxiliary',
    'PMON', 'USD_M', '+',
    'PIB aux prix courants en USD millions. '
    'Indicateur auxiliaire utilisé pour convertir BN.KAC.EOMS.CD '
    '(erreurs et omissions BoP) en % du PIB pour MON_IFF_PRESSURE. '
    'Source : NY.GDP.MKTP.CD (World Bank WDI). '
    'Non exposé directement dans l''API publique.',
    20, TRUE, 'STANDARD', FALSE, FALSE
)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- 2. rf.indicators — ECO_PUBLIC_REV
-- ------------------------------------------------------------

INSERT INTO rf.indicators (
    code, name_fr, name_en, pillar_code, unit_code, direction,
    description, display_order, is_active, imputation_regime,
    is_composite_score, has_structural_zeros
)
VALUES (
    'ECO_PUBLIC_REV',
    'Recettes publiques hors dons (% PIB)',
    'Revenue excluding grants (% GDP)',
    'PECO', 'PCT', '+',
    'Recettes des administrations publiques hors dons (% PIB). '
    'Composante 2 de ECO_PUBLIC_LEAKAGE — croisée avec ECO_TAX '
    'pour mesurer l''efficacité de mobilisation des recettes publiques. '
    'Source : GC.REV.XGRT.GD.ZS (World Bank WDI). '
    'Couverture : 42/54 pays africains (GO confirmé audit 19 mai 2026). '
    'Doctrine OSA : fait observable — données gouvernementales officielles.',
    24, TRUE, 'STANDARD', FALSE, FALSE
)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- 3. collect.source_registry_indicators
--    Liens WB (générique) ↔ nouveaux indicateurs
-- ------------------------------------------------------------

INSERT INTO collect.source_registry_indicators (
    source_id, osa_code, source_code, endpoint, unit, frequency, decision, is_active
)
VALUES
    ('WB', 'MON_GDP_CURRENT', 'NY.GDP.MKTP.CD',
     'https://api.worldbank.org/v2/country/all/indicator/NY.GDP.MKTP.CD?format=json&per_page=20000',
     'USD_CURRENT', 'yearly', 'GO', TRUE),
    ('WB', 'ECO_PUBLIC_REV', 'GC.REV.XGRT.GD.ZS',
     'https://api.worldbank.org/v2/country/all/indicator/GC.REV.XGRT.GD.ZS?format=json&per_page=20000',
     'PCT_GDP', 'yearly', 'GO', TRUE)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 4. collect.indicator_source — liens endpoint WB
-- ------------------------------------------------------------

DO $$
DECLARE v_endpoint_id INTEGER;
BEGIN
    SELECT id INTO v_endpoint_id
    FROM collect.provider_endpoints
    WHERE endpoint_code = 'WB_COUNTRY_INDICATOR' LIMIT 1;

    IF v_endpoint_id IS NULL THEN
        RAISE NOTICE 'Endpoint WB_COUNTRY_INDICATOR non trouvé — ignoré';
        RETURN;
    END IF;

    INSERT INTO collect.indicator_source (
        indicator_code, endpoint_id, source_indicator_code, source_notes, is_active
    )
    VALUES
        ('MON_GDP_CURRENT', v_endpoint_id, 'NY.GDP.MKTP.CD',
         'PIB courant USD. Auxiliaire pour conversion MON_IFF_PRESSURE en % PIB.',
         TRUE),
        ('ECO_PUBLIC_REV',  v_endpoint_id, 'GC.REV.XGRT.GD.ZS',
         'Recettes publiques hors dons % PIB. Composante ECO_PUBLIC_LEAKAGE. '
         'Couverture 42/54 pays GO confirmé audit 19 mai 2026.',
         TRUE)
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Liens indicator_source créés → endpoint %', v_endpoint_id;
END;
$$;

-- ------------------------------------------------------------
-- 5. Vérification finale
-- ------------------------------------------------------------

SELECT code, name_fr, pillar_code, direction, unit_code
FROM rf.indicators
WHERE code IN ('MON_IFF_PRESSURE','MON_GDP_CURRENT','ECO_PUBLIC_REV')
ORDER BY pillar_code, code;

SELECT source_id, osa_code, source_code, decision
FROM collect.source_registry_indicators
WHERE osa_code IN ('MON_IFF_PRESSURE','MON_GDP_CURRENT','ECO_PUBLIC_REV')
ORDER BY osa_code;

COMMIT;
