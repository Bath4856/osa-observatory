-- ============================================================
-- Sprint 23 — Diagnostic préalable
-- 1. État d'ingestion ENV_DEF dans collect.raw_data
-- 2. Localisation de la valeur aberrante AGO 2024 = 63772.36
--    (ENV_FOR — couches L1/L2/L3)
-- ============================================================

-- 1.1 Endpoint GFW_GLOBAL_XLS existe-t-il ?
SELECT id, endpoint_code, provider_id
FROM collect.provider_endpoints
WHERE endpoint_code = 'GFW_GLOBAL_XLS';

-- 1.2 ENV_DEF est-il déjà présent dans collect.raw_data ?
--     (volume attendu si déjà ingéré : ~692 lignes, 49 pays, 2010-2024)
SELECT
    COUNT(*)                              AS nb_lignes,
    COUNT(DISTINCT country_iso3)          AS nb_pays,
    MIN(year)                             AS annee_min,
    MAX(year)                             AS annee_max
FROM collect.raw_data
WHERE indicator_code = 'ENV_DEF';

-- 1.3 Liste des pays couverts (pour comparer aux 49 attendus
--     et identifier les 5 manquants : DJI, ERI, MRT, NER, STP)
SELECT DISTINCT country_iso3
FROM collect.raw_data
WHERE indicator_code = 'ENV_DEF'
ORDER BY country_iso3;

-- 1.4 Vérification rapide AGO 2024 côté ENV_DEF (valeur attendue : 283340.0)
SELECT *
FROM collect.raw_data
WHERE indicator_code = 'ENV_DEF'
  AND country_iso3 = 'AGO'
  AND year = 2024;

-- ============================================================
-- 2. Traçage de la valeur aberrante 63772.36 sur ENV_FOR / AGO / 2024
--    à travers les couches L1 (raw) -> L2 (imputé) -> L3 (normalisé)
-- ============================================================

-- 2.1 Couche L1 — collect.raw_data
SELECT 'L1_raw_data' AS couche, *
FROM collect.raw_data
WHERE indicator_code = 'ENV_FOR'
  AND country_iso3 = 'AGO'
  AND year = 2024;

-- 2.2 Couche L2 — table d'imputation (adapter le nom de schéma/table
--     selon convention réelle, ex. mg.indicator_values_imputed ou
--     imp.indicator_values — à confirmer dans le schéma)
-- SELECT 'L2_imputed' AS couche, *
-- FROM mg.indicator_values_l2
-- WHERE indicator_code = 'ENV_FOR'
--   AND country_iso3 = 'AGO'
--   AND year = 2024;

-- 2.3 Couche L3 — valeurs normalisées (mg.indicator_values ou équivalent)
-- SELECT 'L3_normalized' AS couche, *
-- FROM mg.indicator_values
-- WHERE indicator_code = 'ENV_FOR'
--   AND country_iso3 = 'AGO'
--   AND year = 2024;

-- 2.4 Bornes ENV_FOR sur l'ensemble de la série AGO 2010-2024
--     (pour visualiser le saut d'échelle)
SELECT *
FROM collect.raw_data
WHERE indicator_code = 'ENV_FOR'
  AND country_iso3 = 'AGO'
ORDER BY year;

-- 2.5 Recherche globale de toute valeur ENV_FOR > 100
--     (puisque ENV_FOR est un % de superficie, max théorique = 100)
SELECT *
FROM collect.raw_data
WHERE indicator_code = 'ENV_FOR'
  AND value_raw > 100
ORDER BY country_iso3, year;
