-- ============================================================
-- OSA Observatory — patch_doctrine_reformulation_labels.sql
-- Sprint 9 — Chantier 9F — Mai 2026
--
-- Reformulation des libellés de 3 indicateurs COMPUTED
-- conformément à la Doctrine ISA v1 :
-- Signal d'opportunité souveraine, pas de défaillance.
--
-- Ne modifie PAS : formules, directions ISA, données L3
-- Modifie UNIQUEMENT : name_fr, name_en, description
-- ============================================================

BEGIN;

ALTER TABLE rf.indicators DISABLE TRIGGER trg_protect_indicators;

-- ------------------------------------------------------------
-- 1. MON_IFF_PRESSURE
--    Ancien : "Pression de fuite financière externe"
--    Nouveau : Signal de rétention financière — potentiel de
--              captation monétaire souveraine
-- ------------------------------------------------------------

UPDATE rf.indicators SET
    name_fr     = 'Pression sur la rétention financière externe',
    name_en     = 'External Financial Retention Pressure — Sovereign Capture Potential',
    description = 'Mesure la pression exercée sur les flux financiers externes '
                  '(erreurs et omissions nettes BoP, BN.KAC.EOMS.CD). '
                  'Un signal élevé indique un potentiel de captation monétaire souveraine '
                  'non encore mobilisé — pas nécessairement une fuite illicite. '
                  'Source : IMF BoP républié via World Bank. '
                  'Doctrine OSA v1 : signal d''opportunité souveraine. '
                  'Publication : External Financial Retention Pressure. '
                  'Jamais qualifié de flux criminels sans preuve juridique indépendante.'
WHERE code = 'MON_IFF_PRESSURE';

-- ------------------------------------------------------------
-- 2. MIN_LEAKAGE_RISK
--    Ancien : "Risque de fuite des recettes extractives"
--    Nouveau : Marge de gouvernance extractive — potentiel
--              de rétention souveraine des recettes minières
-- ------------------------------------------------------------

UPDATE rf.indicators SET
    name_fr     = 'Marge de gouvernance extractive — potentiel de rétention souveraine',
    name_en     = 'Extractive Governance Margin — Sovereign Revenue Retention Potential',
    description = 'Écart normalisé entre la rente fossile (PRES_FOSSIL_RENTS_EIA) '
                  'et la gouvernance des recettes extractives déclarées (MIN_GOV/EITI). '
                  'Un écart positif indique une marge de gouvernance mobilisable — '
                  'potentiel de rétention souveraine des recettes extractives. '
                  'Double vérification indépendante EIA/EITI. '
                  'Doctrine OSA v1 : signal d''opportunité souveraine. '
                  'Publication : Extractive Governance Margin. '
                  'Jamais qualifié de corruption sans audit indépendant.'
WHERE code = 'MIN_LEAKAGE_RISK';

-- ------------------------------------------------------------
-- 3. ECO_PUBLIC_LEAKAGE
--    Ancien : "Fuite des finances publiques"
--    Nouveau : Capacité de mobilisation fiscale — écart de
--              performance budgétaire souveraine
-- ------------------------------------------------------------

UPDATE rf.indicators SET
    name_fr     = 'Capacité de mobilisation fiscale — écart de performance budgétaire',
    name_en     = 'Fiscal Mobilisation Capacity — Public Budget Performance Gap',
    description = 'Écart normalisé entre les recettes publiques totales hors dons '
                  '(ECO_PUBLIC_REV) et les recettes fiscales (ECO_TAX). '
                  'Un écart élevé indique un potentiel de mobilisation fiscale '
                  'domestique non encore exploité — opportunité de réduction '
                  'de la dépendance aux recettes non fiscales. '
                  'Sources : GC.REV.XGRT.GD.ZS + GC.TAX.TOTL.GD.ZS (World Bank WDI). '
                  'Doctrine OSA v1 : signal d''opportunité souveraine. '
                  'Publication : Fiscal Mobilisation Capacity. '
                  'Jamais qualifié de malversation sans preuve comptable indépendante.'
WHERE code = 'ECO_PUBLIC_LEAKAGE';

ALTER TABLE rf.indicators ENABLE TRIGGER trg_protect_indicators;

-- ------------------------------------------------------------
-- Vérification
-- ------------------------------------------------------------

SELECT code, name_fr, LEFT(description, 80) AS desc_debut
FROM rf.indicators
WHERE code IN ('MON_IFF_PRESSURE', 'MIN_LEAKAGE_RISK', 'ECO_PUBLIC_LEAKAGE')
ORDER BY code;

COMMIT;
