-- ============================================================
-- OSA — AUDIT 5W1H COMPLET : TRAÇABILITÉ SOURCES PAR PILIER
-- Inclut : fichiers CSV/XLSX/XLS bruts + fetchers Python + scripts
-- Base : osa_db (PostgreSQL 17) | Repo : Bath4856/osa-observatory
-- Mai 2026
-- ============================================================
-- BLOCS :
--   BLOC 0  : Vérification tables collect.*
--   BLOC 1  : Vue maîtresse 5W1H complète
--   BLOC 2  : Synthèse par pilier
--   BLOC 3  : Détail par pilier (10 requêtes)
--   BLOC 4  : Catalogue providers
--   BLOC 5  : Endpoints réels
--   BLOC 6  : Matrice pilier × provider
--   BLOC 7  : Alertes qualité
--   BLOC 8  : Fraîcheur collecte
--   BLOC 9  : Vue persistante ma.v_5w1h_sources
--   BLOC 10 : Inventaire fichiers bruts (table de référence)
--   BLOC 11 : Inventaire fetchers et scripts
-- ============================================================

-- ============================================================
-- BLOC 0 — VÉRIFICATION TABLES
-- ============================================================
\echo '=== BLOC 0 : VÉRIFICATION TABLES COLLECT ==='

SELECT schemaname, tablename,
    CASE WHEN tablename IN (
        'data_providers','provider_endpoints','indicator_source',
        'source_registry','source_registry_indicators',
        'raw_data','ingestion_registry','pipeline_runs'
    ) THEN '✓ PRÉSENTE' ELSE '— ABSENTE' END AS statut
FROM information_schema.tables
WHERE table_schema = 'collect'
  AND tablename IN (
    'data_providers','provider_endpoints','indicator_source',
    'source_registry','source_registry_indicators',
    'raw_data','ingestion_registry','pipeline_runs'
  )
ORDER BY tablename;

-- ============================================================
-- BLOC 1 — VUE MAÎTRESSE 5W1H
-- ============================================================
\echo '=== BLOC 1 : VUE 5W1H MAÎTRESSE ==='

WITH raw_volumes AS (
    SELECT indicator_code,
           COUNT(*)                        AS nb_obs_brutes,
           COUNT(DISTINCT country_iso3)    AS nb_pays_bruts,
           MIN(year)                       AS annee_debut,
           MAX(year)                       AS annee_fin
    FROM collect.raw_data
    WHERE year BETWEEN 2010 AND 2024
    GROUP BY indicator_code
),
processed_volumes AS (
    SELECT indicator_code,
           COUNT(*)                                             AS nb_obs_traitees,
           COUNT(DISTINCT country_iso3)                         AS nb_pays_traites,
           ROUND(AVG(confidence_score)::numeric, 3)             AS confiance_moy,
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
    i.pillar_code                                       AS "PILIER",
    dp.code                                             AS "WHO_provider_code",
    dp.name                                             AS "WHO_provider_nom",
    dp.organisation_type                                AS "WHO_type_org",
    -- WHAT
    i.code                                              AS "WHAT_indicator_code",
    i.name_fr                                           AS "WHAT_indicator_nom",
    i.unit_code                                         AS "WHAT_unite",
    i.direction                                         AS "WHAT_polarite",
    -- WHEN
    COALESCE(rv.annee_debut::text, '—')                 AS "WHEN_debut",
    COALESCE(rv.annee_fin::text,   '—')                 AS "WHEN_fin",
    COALESCE((rv.annee_fin - rv.annee_debut + 1)::text, '—') AS "WHEN_nb_annees",
    -- WHERE
    pe.endpoint_code                                    AS "WHERE_endpoint_code",
    pe.base_url                                         AS "WHERE_url_base",
    cs.source_type                                      AS "WHERE_type_source",
    -- WHY
    p.name_fr                                           AS "WHY_pilier_nom",
    i.description                                       AS "WHY_usage",
    i.imputation_regime                                 AS "WHY_imputation",
    -- HOW
    cs.collection_method                                AS "HOW_methode_collecte",
    cs.update_frequency                                 AS "HOW_frequence",
    cs.last_collected_at                                AS "HOW_derniere_collecte",
    -- VOLUMES
    COALESCE(rv.nb_obs_brutes,   0)                     AS "NB_OBS_BRUTES",
    COALESCE(pv.nb_obs_traitees, 0)                     AS "NB_OBS_TRAITEES",
    COALESCE(pv.nb_pays_traites, 0)                     AS "NB_PAYS",
    COALESCE(pv.confiance_moy,   0)                     AS "CONFIANCE_MOY",
    COALESCE(pv.nb_observed,     0)                     AS "NB_OBSERVED",
    COALESCE(pv.nb_imputed,      0)                     AS "NB_IMPUTED"
FROM rf.indicators i
JOIN rf.pillars p                    ON p.code = i.pillar_code
LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN raw_volumes rv                ON rv.indicator_code = i.code
LEFT JOIN processed_volumes pv          ON pv.indicator_code = i.code
WHERE i.is_active = true
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.pillar_code, dp.code NULLS LAST, i.code;


-- ============================================================
-- BLOC 2 — SYNTHÈSE GLOBALE PAR PILIER
-- ============================================================
\echo '=== BLOC 2 : SYNTHÈSE PAR PILIER ==='

WITH base AS (
    SELECT i.pillar_code, dp.code AS provider_code, pe.base_url,
           i.code AS indicator_code,
           iv.nb_obs, iv.nb_pays, iv.confiance_moy
    FROM rf.indicators i
    LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
    LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
    LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
    LEFT JOIN (
        SELECT indicator_code,
               COUNT(*) nb_obs,
               COUNT(DISTINCT country_iso3) nb_pays,
               ROUND(AVG(confidence_score)::numeric,3) confiance_moy
        FROM ma.indicator_values
        WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
        GROUP BY indicator_code
    ) iv ON iv.indicator_code = i.code
    WHERE i.is_active = true
      AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
)
SELECT
    b.pillar_code                                                AS "Pilier",
    COUNT(DISTINCT b.indicator_code)                             AS "Nb ind.",
    COUNT(DISTINCT b.provider_code)                              AS "Nb providers",
    STRING_AGG(DISTINCT b.provider_code, ', ' ORDER BY b.provider_code) AS "Providers",
    COUNT(DISTINCT b.base_url)                                   AS "Nb endpoints",
    COALESCE(SUM(b.nb_obs), 0)                                   AS "Total obs.",
    COALESCE(MAX(b.nb_pays), 0)                                  AS "Max pays",
    COALESCE(ROUND(AVG(b.confiance_moy)::numeric, 3), 0)         AS "Confiance moy."
FROM base b
GROUP BY b.pillar_code
ORDER BY b.pillar_code;


-- ============================================================
-- BLOC 3 — DÉTAIL PAR PILIER
-- ============================================================

-- Macro réutilisable (sous forme de CTE)
\echo '=== BLOC 3 : DÉTAIL PECO ==='
SELECT i.code, i.name_fr, i.direction,
       dp.code AS provider, pe.base_url, cs.collection_method, cs.update_frequency,
       pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PECO' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PENV ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PENV' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PGEO ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PGEO' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PHUM ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PHUM' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PMIL ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PMIL' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PMIN ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PMIN' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PMON ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PMON' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PNUM ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PNUM' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PRES ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PRES' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;

\echo '=== BLOC 3 : DÉTAIL PTRA ==='
SELECT i.code, i.name_fr, i.direction, dp.code AS provider, pe.base_url,
       cs.collection_method, cs.update_frequency, pv.nb_obs, pv.nb_pays, pv.confiance_moy
FROM rf.indicators i LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp ON dp.id = pe.provider_id
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs, COUNT(DISTINCT country_iso3) nb_pays,
                  ROUND(AVG(confidence_score)::numeric,3) confiance_moy
           FROM ma.indicator_values WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.pillar_code = 'PTRA' AND i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code) ORDER BY i.code;


-- ============================================================
-- BLOC 4 — CATALOGUE PROVIDERS
-- ============================================================
\echo '=== BLOC 4 : CATALOGUE PROVIDERS ==='

SELECT
    dp.code                                                           AS "Provider code",
    dp.name                                                           AS "Provider nom",
    dp.organisation_type                                              AS "Type",
    dp.country_iso3                                                   AS "Pays",
    COUNT(DISTINCT i.pillar_code)                                     AS "Nb piliers",
    COUNT(DISTINCT i.code)                                            AS "Nb indicateurs",
    STRING_AGG(DISTINCT i.pillar_code, ', ' ORDER BY i.pillar_code)  AS "Piliers couverts",
    COUNT(DISTINCT pe.id)                                             AS "Nb endpoints"
FROM collect.data_providers dp
JOIN collect.provider_endpoints pe  ON pe.provider_id = dp.id
JOIN collect.indicator_source cs    ON cs.endpoint_id = pe.id AND cs.is_active
JOIN rf.indicators i                ON i.code = cs.indicator_code AND i.is_active
WHERE NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
GROUP BY dp.code, dp.name, dp.organisation_type, dp.country_iso3
ORDER BY COUNT(DISTINCT i.pillar_code) DESC, dp.code;


-- ============================================================
-- BLOC 5 — ENDPOINTS RÉELS
-- ============================================================
\echo '=== BLOC 5 : ENDPOINTS RÉELS ==='

SELECT
    dp.code                                              AS "Provider",
    pe.endpoint_code                                     AS "Code endpoint",
    pe.base_url                                          AS "URL base",
    pe.endpoint_path                                     AS "Path",
    pe.protocol                                          AS "Protocole",
    pe.auth_type                                         AS "Auth",
    COUNT(DISTINCT cs.indicator_code)                    AS "Nb ind.",
    STRING_AGG(DISTINCT i.pillar_code, ', ')             AS "Piliers"
FROM collect.provider_endpoints pe
JOIN collect.data_providers dp   ON dp.id = pe.provider_id
JOIN collect.indicator_source cs ON cs.endpoint_id = pe.id AND cs.is_active
JOIN rf.indicators i             ON i.code = cs.indicator_code AND i.is_active
WHERE NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
GROUP BY dp.code, pe.endpoint_code, pe.base_url, pe.endpoint_path, pe.protocol, pe.auth_type
ORDER BY COUNT(DISTINCT cs.indicator_code) DESC;


-- ============================================================
-- BLOC 6 — MATRICE PILIER × PROVIDER
-- ============================================================
\echo '=== BLOC 6 : MATRICE PILIER × PROVIDER ==='

SELECT
    i.pillar_code                           AS "Pilier",
    dp.code                                 AS "Provider",
    dp.name                                 AS "Provider nom",
    COUNT(DISTINCT i.code)                  AS "Nb ind.",
    ROUND(COUNT(DISTINCT i.code)::numeric /
          NULLIF(total_p.nb_total, 0) * 100, 1) AS "% pilier"
FROM rf.indicators i
JOIN collect.indicator_source cs   ON cs.indicator_code = i.code AND cs.is_active
JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
JOIN collect.data_providers dp     ON dp.id = pe.provider_id
JOIN (SELECT pillar_code, COUNT(*) nb_total
      FROM rf.indicators
      WHERE is_active AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = code)
      GROUP BY pillar_code) total_p ON total_p.pillar_code = i.pillar_code
WHERE i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
GROUP BY i.pillar_code, dp.code, dp.name, total_p.nb_total
ORDER BY i.pillar_code, COUNT(DISTINCT i.code) DESC;


-- ============================================================
-- BLOC 7 — ALERTES QUALITÉ
-- ============================================================
\echo '=== BLOC 7 : ALERTES — INDICATEURS SANS SOURCE ==='

SELECT
    i.pillar_code                            AS "Pilier",
    i.code                                   AS "Indicateur",
    i.name_fr                                AS "Nom",
    COALESCE(pv.nb_obs::text, '0')           AS "Obs.",
    CASE
        WHEN pv.nb_obs IS NULL OR pv.nb_obs = 0 THEN '🔴 VIDE'
        WHEN pv.nb_obs < 50                      THEN '🟠 FAIBLE (<50)'
        ELSE '🟡 SOURCE NON TRACÉE'
    END                                      AS "Alerte"
FROM rf.indicators i
LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN (SELECT indicator_code, COUNT(*) nb_obs
           FROM ma.indicator_values
           WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
           GROUP BY indicator_code) pv ON pv.indicator_code = i.code
WHERE i.is_active
  AND cs.id IS NULL
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
ORDER BY i.pillar_code, pv.nb_obs DESC NULLS LAST;


-- ============================================================
-- BLOC 8 — FRAÎCHEUR DES DONNÉES
-- ============================================================
\echo '=== BLOC 8 : FRAÎCHEUR PAR SOURCE ==='

SELECT
    dp.code                                                AS "Provider",
    pe.endpoint_code                                       AS "Endpoint",
    MAX(cs.last_collected_at)                              AS "Dernière collecte",
    EXTRACT(DAY FROM NOW() - MAX(cs.last_collected_at))   AS "Jours écoulés",
    COUNT(DISTINCT cs.indicator_code)                      AS "Nb ind.",
    CASE
        WHEN MAX(cs.last_collected_at) IS NULL
             THEN '⚪ JAMAIS'
        WHEN NOW() - MAX(cs.last_collected_at) > INTERVAL '365 days'
             THEN '🔴 OBSOLÈTE (>1 an)'
        WHEN NOW() - MAX(cs.last_collected_at) > INTERVAL '180 days'
             THEN '🟠 VIEILLISSANT (>6 mois)'
        WHEN NOW() - MAX(cs.last_collected_at) > INTERVAL '90 days'
             THEN '🟡 À SURVEILLER (>3 mois)'
        ELSE '🟢 RÉCENT'
    END                                                    AS "Statut fraîcheur"
FROM collect.data_providers dp
JOIN collect.provider_endpoints pe  ON pe.provider_id = dp.id
JOIN collect.indicator_source cs    ON cs.endpoint_id = pe.id AND cs.is_active
GROUP BY dp.code, pe.endpoint_code
ORDER BY MAX(cs.last_collected_at) ASC NULLS FIRST;


-- ============================================================
-- BLOC 9 — VUE PERSISTANTE ma.v_5w1h_sources
-- ============================================================
\echo '=== BLOC 9 : VUE PERSISTANTE ma.v_5w1h_sources ==='

DROP VIEW IF EXISTS ma.v_5w1h_sources CASCADE;

CREATE VIEW ma.v_5w1h_sources AS
SELECT
    i.pillar_code                     AS pilier,
    p.name_fr                         AS pilier_nom,
    dp.code                           AS who_provider_code,
    dp.name                           AS who_provider_nom,
    dp.organisation_type              AS who_type_org,
    dp.country_iso3                   AS who_pays,
    i.code                            AS what_indicator_code,
    i.name_fr                         AS what_indicator_nom,
    i.unit_code                       AS what_unite,
    i.direction                       AS what_polarite,
    pe.endpoint_code                  AS where_endpoint_code,
    pe.base_url                       AS where_url_base,
    pe.protocol                       AS where_protocole,
    cs.source_type                    AS where_type_source,
    cs.collection_method              AS how_methode,
    cs.update_frequency               AS how_frequence,
    cs.last_collected_at              AS how_derniere_collecte,
    i.description                     AS why_usage,
    i.imputation_regime               AS why_imputation
FROM rf.indicators i
JOIN rf.pillars p                     ON p.code = i.pillar_code
LEFT JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active
LEFT JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
LEFT JOIN collect.data_providers dp     ON dp.id = pe.provider_id
WHERE i.is_active
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code);

\echo '✓ Vue ma.v_5w1h_sources créée.'
SELECT COUNT(*) AS nb_lignes FROM ma.v_5w1h_sources;


-- ============================================================
-- BLOC 10 — INVENTAIRE FICHIERS BRUTS (table de référence)
-- Fichiers CSV / XLSX / XLS dans G:\osa-observatory\data\raw\
-- ============================================================
\echo '=== BLOC 10 : INVENTAIRE FICHIERS BRUTS ==='

-- Table de référence documentaire (non chargeable via SQL — voir commentaires)
-- À utiliser comme référence pour vérifier la cohérence avec collect.raw_data

SELECT * FROM (VALUES

    -- ─── PGEO / ACLED ───────────────────────────────────────────────────────
    ('PGEO','ACLED','acled_africa.xlsx',
     'G:\osa-observatory\data\raw\pgeo\acled_africa.xlsx',
     'XLSX','~12 Mo','Événements de conflits Afrique 2010–2024',
     'PGEO_EVT, PGEO_FAT, PGEO_CIV, PGEO_SPR, PGEO_PRE, PGEO_TRD, PGEO_STR, PGEO_INS, PGEO_INT, PGEO_PEAK, GEO_TER, GEO_CON, GEO_RSK',
     'ingest_acled_direct.py — buffers 50km pgeo_site','Mensuelle'),

    ('PGEO','ACLED','acled_civilians_cy.xlsx',
     'G:\osa-observatory\data\raw\pgeo\acled_civilians_cy.xlsx',
     'XLSX','~45 Ko','Ciblage civils agrégé par pays/année',
     'PGEO_CIV',
     'ingest_acled_direct.py','Annuelle'),

    ('PGEO','ACLED','acled_fatalities_cy.xlsx',
     'G:\osa-observatory\data\raw\pgeo\acled_fatalities_cy.xlsx',
     'XLSX','~49 Ko','Fatalités totales par pays/année',
     'PGEO_FAT',
     'ingest_acled_direct.py','Annuelle'),

    ('PGEO','ACLED','acled_violence_cy.xlsx',
     'G:\osa-observatory\data\raw\pgeo\acled_violence_cy.xlsx',
     'XLSX','~46 Ko','Événements de violence par pays/année',
     'PGEO_EVT, GEO_TER',
     'ingest_acled_direct.py','Annuelle'),

    ('PGEO','ACLED','acled_civilian_cy.xlsx',
     'G:\osa-observatory\data\raw\pgeo\acled_civilian_cy.xlsx',
     'XLSX','~45 Ko','Ciblage civils (variante 2)',
     'PGEO_CIV',
     'ingest_acled_direct.py','Annuelle'),

    -- ─── PGEO / WGI ─────────────────────────────────────────────────────────
    ('PGEO','WB_WGI','WGI_Data.csv',
     'G:\osa-observatory\data\raw\pgeo\WGI_Data.csv',
     'CSV','~57 Ko','World Governance Indicators 2010–2024',
     'PGEO_COR, GEO_STAB',
     'fetcher_wb.py — wb_indicator_map.py','Annuelle'),

    -- ─── PGEO/PMIL / UN PKO / UCDP ──────────────────────────────────────────
    ('PGEO/PMIL','IPI/UN PKO','country_level_data.csv',
     'G:\osa-observatory\data\raw\pgeo\country_level_data.csv',
     'CSV','~5 Mo','IPI Peacekeeping Database 1990–2017 (154 pays)',
     'MIL_MIS, GEO_PEA',
     'scripts/ingest_unpk.py — agrégation annuelle Troop Contributions','Archivée (arrêtée 2017)'),

    ('PGEO/PMIL','UCDP','UcdpPrioConflict_v25_1.csv',
     'G:\osa-observatory\data\manual\UcdpPrioConflict_v25_1.csv',
     'CSV','Manuel','UCDP/PRIO Armed Conflict Dataset v25.1',
     'MIL_TER, MIL_DEP, GEO_RSK',
     'Ingestion manuelle SQL','Annuelle (version 2024)'),

    -- ─── PENV / FAO ─────────────────────────────────────────────────────────
    ('PENV','FAO','Forestry_E_Africa.csv',
     'G:\osa-observatory\data\raw\fao\Forestry_E_Africa.csv',
     'CSV','Multi-fichiers','FAOSTAT Foresterie Afrique — production/couverture',
     'ENV_FOR, ENV_ECO',
     'ingest_fao_forest.sql','Annuelle'),

    ('PENV','FAO','Forestry_E_Africa_NOFLAG.csv',
     'G:\osa-observatory\data\raw\fao\Forestry_E_Africa_NOFLAG.csv',
     'CSV','—','FAOSTAT Foresterie sans indicateur qualité',
     'ENV_FOR',
     'ingest_fao_forest.sql — version sans flag','Annuelle'),

    ('PENV','FAO','Forestry_E_Elements.csv',
     'G:\osa-observatory\data\raw\fao\Forestry_E_Elements.csv',
     'CSV','—','Référentiel éléments FAOSTAT Foresterie',
     '(référentiel)','forest_sources.sql','Statique'),

    ('PENV','FAO','Forestry_E_ItemCodes.csv',
     'G:\osa-observatory\data\raw\fao\Forestry_E_ItemCodes.csv',
     'CSV','—','Codes items FAOSTAT Foresterie',
     '(référentiel)','forest_sources.sql','Statique'),

    ('PENV','FAO','Forestry_E_AreaCodes.csv',
     'G:\osa-observatory\data\raw\fao\Forestry_E_AreaCodes.csv',
     'CSV','—','Codes pays FAOSTAT Foresterie',
     '(référentiel)','forest_sources.sql','Statique'),

    ('PENV','FAO','Forestry_E_Flags.csv',
     'G:\osa-observatory\data\raw\fao\Forestry_E_Flags.csv',
     'CSV','—','Indicateurs de qualité FAOSTAT (E=estimé, M=manquant...)',
     '(qualité)','forest_sources.sql','Statique'),

    -- ─── PENV / GFW ─────────────────────────────────────────────────────────
    ('PENV','GFW','global.xlsx',
     'G:\osa-observatory\data\raw\gfw\global.xlsx',
     'XLSX','Multi-onglets','Global Forest Watch — couverture canopée & déforestation',
     'ENV_FOR, ENV_FIS, PRES_CAR (carbone, en attente)',
     'ingest_gfw_forest.sql — generate_gfw.py — check_gfw_thresholds.py','Annuelle'),

    -- ─── PMIN / USGS MCS ────────────────────────────────────────────────────
    ('PMIN','USGS','MCS2025_World_Data.csv',
     'G:\osa-observatory\data\raw\pmin\usgs\MCS2025_World_Data.csv',
     'CSV','~135 Ko','USGS Mineral Commodity Summaries 2025 — données mondiales',
     'MIN_GEO, MIN_CRI, MIN_POT, MIN_RAR',
     'analyze_mcs2025.py — generate_pmin_physical_sql.py — ingest_pmin_physical.sql','Annuelle (MCS)'),

    ('PMIN','USGS','MCS_2024.csv',
     'G:\osa-observatory\data\raw\pmin\usgs\MCS_2024.csv',
     'CSV','~135 Ko','USGS Mineral Commodity Summaries 2024 (version antérieure)',
     'MIN_GEO, MIN_CRI, MIN_POT, MIN_RAR',
     'analyze_mcs2025.py','Archivée'),

    ('PMIN','USGS','MCS_2024_consolidated.csv',
     'G:\osa-observatory\data\raw\pmin\usgs\MCS_2024_consolidated.csv',
     'CSV','~2 Ko','MCS 2024 consolidé pour 20 pays OSA',
     'MIN_GEO, MIN_CRI, MIN_POT, MIN_RAR',
     'ingest_pmin_physical.sql','Consolidée'),

    -- ─── PMIN / USGS MYB ────────────────────────────────────────────────────
    ('PMIN','USGS','myb3-2021-Africa_Summary-ERT.xlsx',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-2021-Africa_Summary-ERT.xlsx',
     'XLSX','~99 Ko','USGS MYB 2021 Africa — T1 (population), T2 (PIB), T3 (production 9 minéraux)',
     'MIN_PRD_BAU, MIN_PRD_ALU, MIN_PRD_CHR, MIN_PRD_COB, MIN_PRD_COP, MIN_PRD_GOL, MIN_PRD_IRN, MIN_PRD_STL, MIN_PRD_MAN',
     'analyze_myb.py — analyze_myb2.py — analyze_myb3.py — generate_pmin_sql.py — ingest_usgs_myb.sql','Ponctuelle (2021)'),

    ('PMIN','USGS','myb3-2019-africa.xlsx',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-2019-africa.xlsx',
     'XLSX','~102 Ko','USGS MYB 2019 Africa — production minière',
     'MIN_PRD_* (9 minéraux)',
     'generate_pmin_sql.py — ingest_usgs_myb.sql','Ponctuelle (2019)'),

    ('PMIN','USGS','myb3-2016-africa-sum.xlsx',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-2016-africa-sum.xlsx',
     'XLSX','~133 Ko','USGS MYB 2016 Africa — production minière',
     'MIN_PRD_* (9 minéraux)',
     'generate_pmin_sql.py — ingest_usgs_myb.sql','Ponctuelle (2016)'),

    ('PMIN','USGS','myb3-sum-2015-africa.xls',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-sum-2015-africa.xls',
     'XLS','~1.8 Mo','USGS MYB 2015 Africa (format legacy)',
     'MIN_PRD_* (9 minéraux)',
     'analyze_usgs.py — generate_pmin_sql.py','Ponctuelle (2015)'),

    ('PMIN','USGS','myb3-sum-2014-africa.xlsx',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-sum-2014-africa.xlsx',
     'XLSX','~264 Ko','USGS MYB 2014 Africa',
     'MIN_PRD_* (9 minéraux)',
     'generate_pmin_sql.py','Ponctuelle (2014)'),

    ('PMIN','USGS','myb3-sum-2013-africa.xls',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-sum-2013-africa.xls',
     'XLS','~486 Ko','USGS MYB 2013 Africa',
     'MIN_PRD_* (9 minéraux)',
     'generate_pmin_sql.py','Ponctuelle (2013)'),

    ('PMIN','USGS','myb3-sum-2012-africa.xls',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-sum-2012-africa.xls',
     'XLS','~282 Ko','USGS MYB 2012 Africa',
     'MIN_PRD_* (9 minéraux)',
     'generate_pmin_sql.py','Ponctuelle (2012)'),

    ('PMIN','USGS','myb3-sum-2011-africa.xls',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-sum-2011-africa.xls',
     'XLS','~302 Ko','USGS MYB 2011 Africa',
     'MIN_PRD_* (9 minéraux)',
     'generate_pmin_sql.py','Ponctuelle (2011)'),

    ('PMIN','USGS','myb3-sum-2010-africa.xls',
     'G:\osa-observatory\data\raw\pmin\usgs\myb3-sum-2010-africa.xls',
     'XLS','~282 Ko','USGS MYB 2010 Africa',
     'MIN_PRD_* (9 minéraux)',
     'generate_pmin_sql.py','Ponctuelle (2010)'),

    -- ─── PMIN / COMTRADE ────────────────────────────────────────────────────
    ('PMIN','COMTRADE','comtrade_minerals_2010_2021.csv',
     'G:\osa-observatory\data\raw\pmin\comtrade\comtrade_minerals_2010_2021.csv',
     'CSV','—','UN Comtrade HS26/71/27 exportations minérales 2010–2021',
     'MIN_EXP, MIN_DEP, MIN_COM',
     'analyze_comtrade.py — generate_comtrade_sql.py — ingest_comtrade_minerals.sql','Annuelle (2010-2021)'),

    ('PMIN','COMTRADE','comtrade_minerals_2022_2024.csv',
     'G:\osa-observatory\data\raw\pmin\comtrade\comtrade_minerals_2022_2024.csv',
     'CSV','—','UN Comtrade HS26/71/27 exportations minérales 2022–2024',
     'MIN_EXP, MIN_DEP, MIN_COM',
     'analyze_comtrade.py — ingest_comtrade_minerals.sql','Annuelle (2022-2024)')

) AS t(
    pilier, provider, fichier, chemin_complet,
    format_fichier, taille, description,
    indicateurs_alimentes, script_ingestion, frequence_maj
);


-- ============================================================
-- BLOC 11 — INVENTAIRE FETCHERS ET SCRIPTS
-- Répertoire : G:\osa-observatory\
-- ============================================================
\echo '=== BLOC 11 : INVENTAIRE FETCHERS ET SCRIPTS ==='

SELECT * FROM (VALUES

    -- ─── FETCHERS PRINCIPAUX ────────────────────────────────────────────────
    ('collectors/fetcher_wb.py',
     'Fetcher World Bank API v2',
     'Collecte automatique 79 indicateurs WB via API REST JSON. Gère les mappings, la pagination, les codes WB → codes OSA. Piliers : PECO, PENV, PHUM, PMIL, PMON, PNUM, PRES, PTRA.',
     'WB API v2 (api.worldbank.org/v2)','Automatique','fetcher_wb.py'),

    ('collectors/wb_indicator_map.py',
     'Mapping WB codes → indicateurs OSA',
     'Dictionnaire de 79 indicateurs WB avec code WB, pilier, direction, unité. Patché par patch_wb_map.py, patch_wb_map2.py, patch_wb_map3.py, fix_wb_map.py.',
     'Référentiel local','Statique (mis à jour manuellement)','wb_indicator_map.py'),

    ('scripts/ingest_acled_direct.py',
     'Ingestion ACLED directe',
     'Lit les fichiers ACLED XLSX (acled_africa.xlsx, acled_fatalities_cy.xlsx, acled_civilians_cy.xlsx, acled_violence_cy.xlsx), calcule buffers 50km autour sites miniers (osa.pgeo_site), insère dans collect.raw_data et osa.pmin_security_event.',
     'Fichiers XLSX locaux + PostGIS','Manuelle (après téléchargement ACLED)','ingest_acled_direct.py'),

    ('scripts/generate_acled_sql.py',
     'Générateur SQL ACLED buffers PMIN',
     'Génère le script db/ingest_acled_pmin.sql. Calcule les événements ACLED dans un rayon de 50km autour des 198 sites miniers géolocalisés.',
     'acled_africa.xlsx + osa.pgeo_site','Manuelle','generate_acled_sql.py'),

    ('scripts/fetcher_pgeo_wikipedia.py',
     'Fetcher géospatial Wikipedia — sites miniers',
     'Scrape Wikipedia pour lister les mines africaines. Géocode via Nominatim (OpenStreetMap API). Insère dans osa.pgeo_site. Alimente PGEO_MINE_COUNT, PGEO_MINE_COORD. Résultat : 198 sites géolocalisés, 24 pays.',
     'Wikipedia API + Nominatim/OSM','Ponctuelle (2023, 27 pays manquants)','fetcher_pgeo_wikipedia.py'),

    -- ─── SCRIPTS ANALYSE / INGESTION USGS ───────────────────────────────────
    ('scripts/analyze_usgs.py',
     'Analyse structure fichiers USGS',
     'Explore la structure des fichiers USGS MCS et MYB (colonnes, formats, couverture pays). Préparatoire à generate_pmin_sql.py.',
     'Fichiers USGS locaux','Analyse préparatoire','analyze_usgs.py'),

    ('scripts/analyze_mcs2025.py',
     'Analyse MCS2025 — indicateurs physiques',
     'Parse MCS2025_World_Data.csv pour extraire MIN_GEO, MIN_CRI, MIN_POT, MIN_RAR pour 20 pays OSA. Normalise les scores 0-1.',
     'MCS2025_World_Data.csv','Ponctuelle (MCS2025)','analyze_mcs2025.py'),

    ('scripts/analyze_myb.py',
     'Analyse MYB Africa — version 1',
     'Explore les sheets T1 (population), T2 (PIB), T3 (production minérale) des fichiers MYB. Identifie les pays africains et les colonnes minéraux.',
     'myb3-*.xlsx / *.xls','Analyse préparatoire','analyze_myb.py'),

    ('scripts/analyze_myb2.py',
     'Analyse MYB Africa — version 2',
     'Analyse approfondie T3-Africa : en-têtes multi-lignes, 9 minéraux (cobalt, or, manganèse, cuivre, fer, aluminium, chrome, acier, bauxite).',
     'myb3-2021-Africa_Summary-ERT.xlsx','Analyse préparatoire','analyze_myb2.py'),

    ('scripts/analyze_myb3.py',
     'Analyse MYB Africa — version 3',
     'Explore sheets T1, T2, T3 des MYB 2021. Identifie toutes les colonnes minéraux.',
     'myb3-2021-Africa_Summary-ERT.xlsx','Analyse préparatoire','analyze_myb3.py'),

    ('scripts/generate_pmin_sql.py',
     'Générateur SQL ingestion USGS MYB',
     'Parse les fichiers MYB 2010–2021 (XLS/XLSX), extrait production par pays et minéral, génère db/ingest_usgs_myb.sql. Résultat : 511 observations, 9 minéraux, 3 millésimes (2016, 2019, 2021).',
     'myb3-*.xlsx + osa_map (ISO3)','Ponctuelle (après téléchargement MYB)','generate_pmin_sql.py'),

    ('scripts/generate_pmin_physical_sql.py',
     'Générateur SQL PMIN physique (MCS)',
     'Parse MCS2025_World_Data.csv, normalise MIN_GEO/CRI/POT/RAR sur [0,1], génère db/ingest_pmin_physical.sql.',
     'MCS2025_World_Data.csv','Ponctuelle (annuelle MCS)','generate_pmin_physical_sql.py'),

    -- ─── SCRIPTS ANALYSE / INGESTION COMTRADE ───────────────────────────────
    ('scripts/analyze_comtrade.py',
     'Analyse structure CSV COMTRADE',
     'Explore comtrade_minerals_2010_2021.csv : colonnes HS, pays, valeurs. Préparatoire à generate_comtrade_sql.py.',
     'comtrade_minerals_2010_2021.csv','Analyse préparatoire','analyze_comtrade.py'),

    ('scripts/generate_comtrade_sql.py',
     'Générateur SQL ingestion COMTRADE',
     'Parse les CSV COMTRADE HS26/71/27, mappe vers MIN_EXP/MIN_DEP/MIN_COM, génère db/ingest_comtrade_minerals.sql. Résultat : 1 613 observations, 46 pays, 2010–2024.',
     'comtrade_minerals_2010_2021.csv + comtrade_minerals_2022_2024.csv','Annuelle','generate_comtrade_sql.py'),

    -- ─── SCRIPTS MAPPING PGEO ───────────────────────────────────────────────
    ('scripts/map_pgeo_resources.py',
     'Mapping ressources → sites miniers',
     'Mappe les mots-clés Wikipedia (diamond, gold, copper…) vers les resource_id de osa.mineral_resource. Résultat : 67 sites supplémentaires mappés (total 111/198).',
     'osa.pgeo_site + osa.mineral_mapping','Ponctuelle','map_pgeo_resources.py'),

    ('scripts/clean_pgeo_sites.py',
     'Nettoyage et completion osa.pgeo_site',
     'Supprime les footnotes bibliographiques Wikipedia (23 lignes). Mappe 4 sites supplémentaires. Bilan final : 198 sites, 111 avec resource_id, 24 pays.',
     'osa.pgeo_site','Ponctuelle','clean_pgeo_sites.py'),

    -- ─── SCRIPTS FORÊT / GFW ────────────────────────────────────────────────
    ('scripts/generate_gfw.py',
     'Générateur SQL ingestion GFW',
     'Parse global.xlsx (Global Forest Watch), extrait les données de couverture canopée et déforestation, génère db/ingest_gfw_forest.sql.',
     'data/raw/gfw/global.xlsx','Annuelle','generate_gfw.py'),

    ('scripts/check_gfw_thresholds.py',
     'Vérification seuils GFW',
     'Contrôle les seuils de détection de déforestation GFW. Valide la cohérence entre les seuils de canopée (10%, 25%, 50%) et les données ingérées.',
     'data/raw/gfw/global.xlsx','Contrôle qualité','check_gfw_thresholds.py'),

    -- ─── SCRIPTS PATCH WB INDICATOR MAP ────────────────────────────────────
    ('scripts/patch_wb_map.py',
     'Patch wb_indicator_map.py — version 1',
     'Ajoute les indicateurs ENV (9 nouveaux : ENV_PRO, ENV_WAT, ENV_LAN, ENV_FIS, ENV_SOL, ENV_WAS, ENV_RSK, ENV_ADA, ENV_ECO) suite à la correction des codes WB pour PENV.',
     'collectors/wb_indicator_map.py','Ponctuelle','patch_wb_map.py'),

    ('scripts/patch_wb_map2.py',
     'Patch wb_indicator_map.py — version 2',
     'Corrige les codes WB erronés pour PMIL et PNUM. Archive : collectors/archive/wb_indicator_map_patch_wgi_*.bak',
     'collectors/wb_indicator_map.py','Ponctuelle','patch_wb_map2.py'),

    ('scripts/patch_wb_map3.py',
     'Patch wb_indicator_map.py — version 3',
     'Corrige les codes PRES et PTRA. Archive : collectors/archive/wb_indicator_map_pres_*.bak + ptra_*.bak',
     'collectors/wb_indicator_map.py','Ponctuelle','patch_wb_map3.py'),

    ('scripts/fix_wb_map.py',
     'Correction syntaxique wb_indicator_map.py',
     'Corrige un problème d'indentation dans wb_indicator_map.py causé par merge_patches.py. Sépare le dictionnaire actif du dictionnaire CANDIDATE_INDICATORS.',
     'collectors/wb_indicator_map.py','Ponctuelle','fix_wb_map.py'),

    ('scripts/merge_patches.py',
     'Merge des patches wb_indicator_map.py',
     'Fusionne les différents patches successifs en un seul fichier wb_indicator_map.py cohérent.',
     'collectors/wb_indicator_map.py','Ponctuelle','merge_patches.py'),

    -- ─── SCRIPTS INGESTION UNPK ─────────────────────────────────────────────
    ('scripts/ingest_unpk.py',
     'Ingestion IPI Peacekeeping Database',
     'Parse country_level_data.csv (5 Mo, 30 096 lignes, 1990–2017). Agrège les Troop Contributions annuelles pour 48 pays OSA. Génère SQL pour MIL_MIS et GEO_PEA.',
     'data/raw/pgeo/country_level_data.csv','Ponctuelle (2017 max, HDX pour 2018-2024)','ingest_unpk.py')

) AS t(
    chemin_script, nom_script, description,
    source_fichier, frequence, fichier_script
);

\echo '=== AUDIT 5W1H COMPLET AVEC FICHIERS BRUTS ET FETCHERS — FIN ==='

-- ============================================================
-- EXPORT CSV (décommenter pour utiliser)
-- ============================================================
-- \COPY (SELECT * FROM ma.v_5w1h_sources ORDER BY pilier, what_indicator_code)
-- TO 'G:\osa-observatory\data\exports\audit_5w1h_sources.csv'
-- WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'UTF8');
