-- ============================================================
-- OSA — AUDIT 5W1H COMPLET : TRAÇABILITÉ DES SOURCES PAR PILIER
-- Base : osa_db (PostgreSQL 17)
-- Schémas : rf, collect, ma
-- Auteur  : OSA Observatory
-- Date    : Mai 2026
-- ============================================================
-- STRUCTURE DU SCRIPT
--   BLOC 0  : Vérification préalable des tables nécessaires
--   BLOC 1  : Vue maîtresse 5W1H (WHO/WHAT/WHEN/WHERE/WHY/HOW)
--   BLOC 2  : Résumé global par pilier (synthèse)
--   BLOC 3  : Détail par pilier (1 requête par pilier)
--   BLOC 4  : Providers distincts et leur couverture piliers
--   BLOC 5  : Endpoints réels (URL collecte)
--   BLOC 6  : Matrice pilier × provider (couverture croisée)
--   BLOC 7  : Alertes qualité traçabilité
--   BLOC 8  : Statistiques de fraîcheur (dernière collecte)
--   BLOC 9  : Vue persistante pour rapport
-- ============================================================

-- ============================================================
-- BLOC 0 — VÉRIFICATION DES TABLES
-- ============================================================

SELECT
    schemaname,
    tablename,
    CASE
        WHEN tablename IN (
            'data_providers','provider_endpoints','indicator_source',
            'source_registry','source_registry_indicators',
            'raw_data','ingestion_registry','pipeline_runs'
        ) THEN '✓ PRÉSENTE'
        ELSE '— ABSENTE'
    END AS statut
FROM information_schema.tables
WHERE table_schema = 'collect'
  AND tablename IN (
    'data_providers','provider_endpoints','indicator_source',
    'source_registry','source_registry_indicators',
    'raw_data','ingestion_registry','pipeline_runs'
  )
ORDER BY tablename;

-- ============================================================
-- BLOC 1 — VUE MAÎTRESSE 5W1H COMPLÈTE
-- Jointure : rf.indicators → collect.indicator_source
--          → collect.provider_endpoints → collect.data_providers
--          + volumes réels depuis collect.raw_data
-- ============================================================

\echo '=== BLOC 1 : VUE 5W1H MAÎTRESSE ==='

WITH raw_volumes AS (
    -- Volumes réels par indicator_code (toutes années confondues)
    SELECT
        indicator_code,
        COUNT(*)                        AS nb_obs_brutes,
        COUNT(DISTINCT country_iso3)    AS nb_pays_bruts,
        MIN(year)                       AS annee_debut_brut,
        MAX(year)                       AS annee_fin_brut
    FROM collect.raw_data
    WHERE year BETWEEN 2010 AND 2024
    GROUP BY indicator_code
),
processed_volumes AS (
    -- Volumes traités depuis ma.indicator_values
    SELECT
        indicator_code,
        COUNT(*)                        AS nb_obs_traitees,
        COUNT(DISTINCT country_iso3)    AS nb_pays_traites,
        ROUND(AVG(confidence_score)::numeric, 3) AS confiance_moy,
        SUM(CASE WHEN value_status = 'OBSERVED'     THEN 1 ELSE 0 END) AS nb_observed,
        SUM(CASE WHEN value_status = 'IMPUTED'      THEN 1 ELSE 0 END) AS nb_imputed,
        SUM(CASE WHEN value_status = 'INTERPOLATED' THEN 1 ELSE 0 END) AS nb_interpolated
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024
      AND processed_value IS NOT NULL
    GROUP BY indicator_code
)
SELECT
    -- WHO
    i.pillar_code                                   AS "PILIER",
    dp.code                                         AS "WHO_provider_code",
    dp.name                                         AS "WHO_provider_nom",
    dp.organisation_type                            AS "WHO_type_org",

    -- WHAT
    i.code                                          AS "WHAT_indicator_code",
    i.name_fr                                       AS "WHAT_indicator_nom",
    i.unit_code                                     AS "WHAT_unite",
    i.direction                                     AS "WHAT_polarite",

    -- WHEN
    COALESCE(rv.annee_debut_brut::text, '—')        AS "WHEN_debut",
    COALESCE(rv.annee_fin_brut::text,  '—')        AS "WHEN_fin",
    COALESCE((rv.annee_fin_brut - rv.annee_debut_brut + 1)::text, '—') AS "WHEN_nb_annees",

    -- WHERE
    pe.endpoint_code                                AS "WHERE_endpoint_code",
    pe.base_url                                     AS "WHERE_url_base",
    cs.source_type                                  AS "WHERE_type_source",

    -- WHY
    p.name_fr                                       AS "WHY_pilier_nom",
    i.description                                   AS "WHY_usage",
    i.imputation_regime                             AS "WHY_regime_imputation",

    -- HOW
    cs.collection_method                            AS "HOW_methode",
    cs.update_frequency                             AS "HOW_frequence",
    cs.last_collected_at                            AS "HOW_derniere_collecte",

    -- VOLUMES
    COALESCE(rv.nb_obs_brutes,    0)               AS "NB_OBS_BRUTES",
    COALESCE(pv.nb_obs_traitees,  0)               AS "NB_OBS_TRAITEES",
    COALESCE(pv.nb_pays_traites,  0)               AS "NB_PAYS",
    COALESCE(pv.confiance_moy,    0)               AS "CONFIANCE_MOY",
    COALESCE(pv.nb_observed,      0)               AS "NB_OBSERVED",
    COALESCE(pv.nb_imputed,       0)               AS "NB_IMPUTED"

FROM rf.indicators i
JOIN rf.pillars p                    ON p.code = i.pillar_code
LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code
                                     AND cs.is_active = true
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN raw_volumes rv                ON rv.indicator_code = i.code
LEFT JOIN processed_volumes pv          ON pv.indicator_code = i.code
WHERE i.is_active = true
  AND NOT EXISTS (
      SELECT 1 FROM ma.indicator_exclusions e
      WHERE e.indicator_code = i.code
  )
ORDER BY i.pillar_code, dp.code NULLS LAST, i.code;


-- ============================================================
-- BLOC 2 — RÉSUMÉ GLOBAL PAR PILIER
-- ============================================================

\echo '=== BLOC 2 : SYNTHÈSE PAR PILIER ==='

WITH base AS (
    SELECT
        i.pillar_code,
        dp.code             AS provider_code,
        dp.name             AS provider_nom,
        pe.base_url,
        i.code              AS indicator_code,
        iv.nb_obs,
        iv.nb_pays,
        iv.confiance_moy
    FROM rf.indicators i
    LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
    LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
    LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
    LEFT JOIN (
        SELECT indicator_code,
               COUNT(*) nb_obs,
               COUNT(DISTINCT country_iso3) nb_pays,
               ROUND(AVG(confidence_score)::numeric, 3) confiance_moy
        FROM ma.indicator_values
        WHERE year BETWEEN 2010 AND 2024
          AND processed_value IS NOT NULL
        GROUP BY indicator_code
    ) iv ON iv.indicator_code = i.code
    WHERE i.is_active = true
      AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
)
SELECT
    b.pillar_code                                               AS "Pilier",
    COUNT(DISTINCT b.indicator_code)                            AS "Nb ind.",
    COUNT(DISTINCT b.provider_code)                             AS "Nb providers",
    STRING_AGG(DISTINCT b.provider_code, ', ' ORDER BY b.provider_code) AS "Providers",
    COUNT(DISTINCT b.base_url)                                  AS "Nb endpoints",
    COALESCE(SUM(b.nb_obs), 0)                                  AS "Total obs.",
    COALESCE(MAX(b.nb_pays), 0)                                 AS "Max pays",
    COALESCE(ROUND(AVG(b.confiance_moy)::numeric, 3), 0)        AS "Confiance moy."
FROM base b
GROUP BY b.pillar_code
ORDER BY b.pillar_code;


-- ============================================================
-- BLOC 3 — DÉTAIL PAR PILIER (10 sections)
-- ============================================================

\echo '=== BLOC 3 : DÉTAIL PECO ==='
SELECT
    i.code, i.name_fr, i.direction,
    dp.code AS provider, pe.base_url,
    cs.collection_method, cs.update_frequency,
    pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code,
           COUNT(*) nb_obs,
           COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PECO' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PENV ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PENV' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PGEO ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PGEO' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PHUM ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PHUM' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PMIL ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PMIL' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PMIN ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PMIN' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PMON ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PMON' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PNUM ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PNUM' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PRES ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PRES' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PTRA ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric,3) confiance_moy
    FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PTRA' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;


-- ============================================================
-- BLOC 4 — PROVIDERS DISTINCTS ET LEUR COUVERTURE PILIERS
-- ============================================================

\echo '=== BLOC 4 : PROVIDERS ET COUVERTURE PILIERS ==='

SELECT
    dp.code                                                     AS "Provider code",
    dp.name                                                     AS "Provider nom",
    dp.organisation_type                                        AS "Type",
    dp.country_iso3                                             AS "Pays",
    COUNT(DISTINCT i.pillar_code)                               AS "Nb piliers",
    COUNT(DISTINCT i.code)                                      AS "Nb indicateurs",
    STRING_AGG(DISTINCT i.pillar_code, ', ' ORDER BY i.pillar_code) AS "Piliers couverts",
    COUNT(DISTINCT pe.id)                                       AS "Nb endpoints"
FROM collect.data_providers dp
JOIN collect.provider_endpoints pe   ON pe.provider_id = dp.id
JOIN collect.indicator_source cs     ON cs.endpoint_id = pe.id AND cs.is_active
JOIN rf.indicators i                 ON i.code = cs.indicator_code AND i.is_active
WHERE NOT EXISTS (
    SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code
)
GROUP BY dp.code, dp.name, dp.organisation_type, dp.country_iso3
ORDER BY COUNT(DISTINCT i.pillar_code) DESC, dp.code;


-- ============================================================
-- BLOC 5 — ENDPOINTS RÉELS (URLS DE COLLECTE)
-- ============================================================

\echo '=== BLOC 5 : ENDPOINTS RÉELS ==='

SELECT
    dp.code                         AS "Provider",
    pe.endpoint_code                AS "Code endpoint",
    pe.base_url                     AS "URL base",
    pe.endpoint_path                AS "Path",
    pe.protocol                     AS "Protocole",
    pe.auth_type                    AS "Authentification",
    COUNT(DISTINCT cs.indicator_code) AS "Nb ind. connectés",
    STRING_AGG(DISTINCT i.pillar_code, ', ') AS "Piliers"
FROM collect.provider_endpoints pe
JOIN collect.data_providers dp      ON dp.id = pe.provider_id
JOIN collect.indicator_source cs    ON cs.endpoint_id = pe.id AND cs.is_active
JOIN rf.indicators i                ON i.code = cs.indicator_code AND i.is_active
WHERE NOT EXISTS (
    SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code
)
GROUP BY dp.code, pe.endpoint_code, pe.base_url, pe.endpoint_path,
         pe.protocol, pe.auth_type
ORDER BY COUNT(DISTINCT cs.indicator_code) DESC;


-- ============================================================
-- BLOC 6 — MATRICE PILIER × PROVIDER
-- (couverture croisée : combien d'indicateurs par cellule)
-- ============================================================

\echo '=== BLOC 6 : MATRICE PILIER × PROVIDER ==='

SELECT
    i.pillar_code                   AS "Pilier",
    dp.code                         AS "Provider",
    dp.name                         AS "Provider nom",
    COUNT(DISTINCT i.code)          AS "Nb ind.",
    ROUND(
        COUNT(DISTINCT i.code)::numeric /
        NULLIF(total_pilier.nb_total_ind, 0) * 100
    , 1)                            AS "% couverture pilier"
FROM rf.indicators i
JOIN collect.indicator_source cs    ON cs.indicator_code = i.code AND cs.is_active
JOIN collect.provider_endpoints pe  ON pe.id = cs.endpoint_id
JOIN collect.data_providers dp      ON dp.id = pe.provider_id
JOIN (
    SELECT pillar_code, COUNT(*) nb_total_ind
    FROM rf.indicators
    WHERE is_active = true
      AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = code)
    GROUP BY pillar_code
) total_pilier ON total_pilier.pillar_code = i.pillar_code
WHERE i.is_active = true
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
GROUP BY i.pillar_code, dp.code, dp.name, total_pilier.nb_total_ind
ORDER BY i.pillar_code, COUNT(DISTINCT i.code) DESC;


-- ============================================================
-- BLOC 7 — ALERTES QUALITÉ TRAÇABILITÉ
-- Indicateurs actifs sans source connectée
-- ============================================================

\echo '=== BLOC 7 : ALERTES QUALITÉ — INDICATEURS SANS SOURCE ==='

SELECT
    i.pillar_code                   AS "Pilier",
    i.code                          AS "Indicateur",
    i.name_fr                       AS "Nom",
    i.unit_code                     AS "Unité",
    COALESCE(pv.nb_obs::text, '0')  AS "Obs. actuelles",
    CASE
        WHEN pv.nb_obs IS NULL OR pv.nb_obs = 0 THEN '🔴 VIDE — aucune donnée'
        WHEN pv.nb_obs < 50          THEN '🟠 FAIBLE — < 50 observations'
        ELSE                              '🟡 SOURCE MANQUANTE — données présentes mais non tracées'
    END                             AS "Alerte"
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) pv ON pv.indicator_code = i.code
WHERE i.is_active = true
  AND cs.id IS NULL  -- pas de source connectée
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.pillar_code, pv.nb_obs DESC NULLS LAST;


-- ============================================================
-- BLOC 8 — FRAÎCHEUR DES DONNÉES (DERNIÈRE COLLECTE)
-- ============================================================

\echo '=== BLOC 8 : FRAÎCHEUR — DERNIÈRE COLLECTE PAR SOURCE ==='

SELECT
    dp.code                                             AS "Provider",
    dp.name                                             AS "Nom",
    pe.endpoint_code                                    AS "Endpoint",
    MAX(cs.last_collected_at)                           AS "Dernière collecte",
    EXTRACT(DAY FROM NOW() - MAX(cs.last_collected_at)) AS "Jours depuis collecte",
    COUNT(DISTINCT cs.indicator_code)                   AS "Nb indicateurs",
    CASE
        WHEN MAX(cs.last_collected_at) IS NULL
             THEN '⚪ JAMAIS COLLECTÉ'
        WHEN NOW() - MAX(cs.last_collected_at) > INTERVAL '365 days'
             THEN '🔴 OBSOLÈTE (> 1 an)'
        WHEN NOW() - MAX(cs.last_collected_at) > INTERVAL '180 days'
             THEN '🟠 VIEILLISSANT (> 6 mois)'
        WHEN NOW() - MAX(cs.last_collected_at) > INTERVAL '90 days'
             THEN '🟡 À SURVEILLER (> 3 mois)'
        ELSE '🟢 RÉCENT'
    END                                                 AS "Statut fraîcheur"
FROM collect.data_providers dp
JOIN collect.provider_endpoints pe  ON pe.provider_id = dp.id
JOIN collect.indicator_source cs    ON cs.endpoint_id = pe.id AND cs.is_active
GROUP BY dp.code, dp.name, pe.endpoint_code
ORDER BY MAX(cs.last_collected_at) ASC NULLS FIRST;


-- ============================================================
-- BLOC 9 — VUE PERSISTANTE POUR RAPPORT ET TABLEAUX DE BORD
-- Crée (ou remplace) une vue matérialisée dans le schéma ma
-- ============================================================

\echo '=== BLOC 9 : CRÉATION VUE PERSISTANTE ma.v_5w1h_sources ==='

DROP VIEW IF EXISTS ma.v_5w1h_sources CASCADE;

CREATE VIEW ma.v_5w1h_sources AS
SELECT
    i.pillar_code                       AS pilier,
    p.name_fr                           AS pilier_nom,
    dp.code                             AS who_provider_code,
    dp.name                             AS who_provider_nom,
    dp.organisation_type                AS who_type_org,
    dp.country_iso3                     AS who_pays,
    i.code                              AS what_indicator_code,
    i.name_fr                           AS what_indicator_nom,
    i.unit_code                         AS what_unite,
    i.direction                         AS what_polarite,
    pe.endpoint_code                    AS where_endpoint_code,
    pe.base_url                         AS where_url_base,
    pe.protocol                         AS where_protocole,
    cs.source_type                      AS where_type_source,
    cs.collection_method                AS how_methode,
    cs.update_frequency                 AS how_frequence,
    cs.last_collected_at                AS how_derniere_collecte,
    i.description                       AS why_usage,
    i.imputation_regime                 AS why_imputation
FROM rf.indicators i
JOIN rf.pillars p                        ON p.code = i.pillar_code
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
WHERE i.is_active = true
  AND NOT EXISTS (
      SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code
  );

\echo '✓ Vue ma.v_5w1h_sources créée.'

-- Vérification
SELECT COUNT(*) AS nb_lignes FROM ma.v_5w1h_sources;


-- ============================================================
-- BLOC BONUS — EXPORT CSV (décommenter pour utiliser)
-- ============================================================

-- \COPY (SELECT * FROM ma.v_5w1h_sources ORDER BY pilier, what_indicator_code)
-- TO 'G:\osa-observatory\data\exports\audit_5w1h_sources.csv'
-- WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'UTF8');

\echo '=== AUDIT 5W1H COMPLET — FIN ==='
