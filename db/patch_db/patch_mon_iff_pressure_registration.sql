-- ============================================================
-- OSA Observatory — patch_mon_iff_pressure_registration.sql
-- Sprint 8 — Mai 2026
--
-- Enregistrement de MON_IFF_PRESSURE dans l'architecture OSA.
--
-- Indicateur : MON_IFF_PRESSURE
-- Pilier      : PMON — Souveraineté monétaire
-- Direction   : − (écart comptable élevé = fuite = pression souveraine)
-- Source      : BN.KAC.EOMS.CD — Net errors and omissions, BoP
--               World Bank Open Data / IMF Balance of Payments
-- Couverture  : 52/54 pays africains — 1960–2024 (SOM manquant)
-- Statut audit: GO — testé le 19 mai 2026
--
-- Dépendances vérifiées :
--   collect.data_providers  WB    (id=1)  — EXISTANT
--   collect.provider_endpoints WB_COUNTRY_INDICATOR (id=1) — EXISTANT
--   collect.source_registry WB (id=11) — EXISTANT (générique)
--   → Création WB_BOP source spécifique BoP
--   rf.indicators MON_IFF_PRESSURE — À CRÉER
--   collect.source_registry_indicators — À CRÉER
--
-- Contraintes vérifiées :
--   source_registry.status : GO | PILOT | NO_GO
--   source_registry.api_type : REST | API_JSON | CSV_BULK | MANUAL | etc.
--   provider_endpoints.output_format : json | csv | xml | xlsx
--   mm.source_origins.update_frequency : daily | monthly | quarterly | yearly | irregular
--
-- Idempotent — peut être rejoué.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. mm.source_origins — WB déjà enregistré (id=1)
--    Vérification uniquement — pas de nouvel enregistrement
-- ------------------------------------------------------------

DO $$
DECLARE v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM mm.source_origins WHERE code = 'WB';
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'mm.source_origins WB introuvable — vérifier OSA_DEPLOY_V1.sql';
    END IF;
    RAISE NOTICE 'mm.source_origins WB confirmé : id=%', v_id;
END;
$$;

-- ------------------------------------------------------------
-- 2. collect.data_providers — WB (id=1) existant
--    Vérification uniquement
-- ------------------------------------------------------------

DO $$
DECLARE v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM collect.data_providers WHERE code = 'WB';
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'collect.data_providers WB introuvable';
    END IF;
    RAISE NOTICE 'collect.data_providers WB confirmé : id=%', v_id;
END;
$$;

-- ------------------------------------------------------------
-- 3. collect.source_registry — WB_BOP (nouveau)
--    Source spécifique Balance of Payments / IMF BoP via WB
--    Distinct de la source WB générique (id=11)
-- ------------------------------------------------------------

INSERT INTO collect.source_registry (
    source_id, name, organization, api_type, base_url,
    status, priority, coverage, stability, limits, reason,
    freshness_score, completeness_score, reliability_score,
    is_active
)
VALUES (
    'WB_BOP',
    'World Bank — Balance of Payments Statistics (IMF BoP)',
    'World Bank Open Data / International Monetary Fund',
    'REST',
    'https://api.worldbank.org/v2/country/all/indicator/BN.KAC.EOMS.CD',
    'GO',
    1,
    'Afrique : 52/54 pays | 1960–2024 | SOM manquant',
    'Données IMF BoP républiées via WB API — stable, annuelle',
    'Téléchargement via API JSON. Décalage publication 12–18 mois. '
    'Valeurs en USD courants — conversion % PIB requise dans le fetcher.',
    'BN.KAC.EOMS.CD — Erreurs et omissions nettes de la balance des paiements. '
    'Proxy standard des flux financiers non enregistrés utilisé par GFI, OCDE et FMI. '
    'Fait comptable observable — conforme doctrine OSA d''observation comportementale. '
    'Publier comme pression de fuite financière externe, pas comme preuve de flux criminels. '
    'Testé le 19 mai 2026 — statut GO confirmé.',
    0.85,
    0.88,
    0.90,
    TRUE
)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 4. rf.indicators — MON_IFF_PRESSURE (nouveau)
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
    'MON_IFF_PRESSURE',
    'Pression de fuite financière externe (erreurs et omissions BoP % PIB)',
    'External Financial Leakage Pressure (BoP errors and omissions % GDP)',
    'PMON',
    'PCT',
    '-',
    'Erreurs et omissions nettes de la balance des paiements en % du PIB. '
    'Proxy standard des flux financiers non enregistrés (GFI, OCDE, FMI). '
    'Un écart négatif important indique une fuite financière externe non enregistrée '
    'qui affaiblit la souveraineté monétaire. '
    'Source : BN.KAC.EOMS.CD (World Bank / IMF BoP). '
    'Couverture : 52/54 pays africains 2010–2024 (SOM manquant — imputé par MICE). '
    'Note de publication : libellé External Financial Leakage Pressure — '
    'ne pas qualifier de flux illicites sans preuve juridique indépendante. '
    'Conforme doctrine OSA d''observation comportementale.',
    19,
    TRUE,
    'STANDARD',
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
-- 5. collect.source_registry_indicators — lien WB_BOP ↔ MON_IFF_PRESSURE
-- ------------------------------------------------------------

INSERT INTO collect.source_registry_indicators (
    source_id, osa_code, source_code, endpoint, unit, frequency, decision, is_active
)
VALUES (
    'WB_BOP',
    'MON_IFF_PRESSURE',
    'BN.KAC.EOMS.CD',
    'https://api.worldbank.org/v2/country/all/indicator/BN.KAC.EOMS.CD?format=json&per_page=20000',
    'USD_CURRENT',
    'yearly',
    'GO',
    TRUE
)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 6. collect.indicator_source — lien indicateur ↔ endpoint WB
-- ------------------------------------------------------------

DO $$
DECLARE
    v_endpoint_id INTEGER;
    v_source_id   INTEGER;
BEGIN
    SELECT id INTO v_endpoint_id
    FROM collect.provider_endpoints
    WHERE endpoint_code = 'WB_COUNTRY_INDICATOR'
    LIMIT 1;

    SELECT id INTO v_source_id
    FROM collect.source_registry
    WHERE source_id = 'WB_BOP'
    LIMIT 1;

    IF v_endpoint_id IS NULL THEN
        RAISE NOTICE 'Endpoint WB_COUNTRY_INDICATOR non trouvé — lien indicator_source ignoré';
        RETURN;
    END IF;

    INSERT INTO collect.indicator_source (
        indicator_code, endpoint_id, source_indicator_code,
        source_notes, is_active
    )
    VALUES (
        'MON_IFF_PRESSURE',
        v_endpoint_id,
        'BN.KAC.EOMS.CD',
        'Net errors and omissions, BoP (USD courants). '
        'Conversion % PIB requise dans le fetcher : diviser par NY.GDP.MKTP.CD. '
        'Testé GO le 19 mai 2026 — 52/54 pays africains.',
        TRUE
    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Lien indicator_source créé : MON_IFF_PRESSURE → endpoint %', v_endpoint_id;
END;
$$;

-- ------------------------------------------------------------
-- 7. Vérification finale complète
-- ------------------------------------------------------------

SELECT 'mm.source_origins WB'          AS element, id::text, code, name AS detail
FROM mm.source_origins WHERE code = 'WB'

UNION ALL

SELECT 'collect.source_registry WB_BOP', id::text, source_id, status
FROM collect.source_registry WHERE source_id = 'WB_BOP'

UNION ALL

SELECT 'rf.indicators MON_IFF_PRESSURE', code, pillar_code,
    direction || ' | ' || imputation_regime || ' | ' || unit_code
FROM rf.indicators WHERE code = 'MON_IFF_PRESSURE'

UNION ALL

SELECT 'source_registry_indicators', source_id, osa_code, decision
FROM collect.source_registry_indicators WHERE osa_code = 'MON_IFF_PRESSURE'

UNION ALL

SELECT 'indicator_source', indicator_code,
    'endpoint_id=' || endpoint_id::text, source_indicator_code
FROM collect.indicator_source WHERE indicator_code = 'MON_IFF_PRESSURE'

ORDER BY element;

COMMIT;
