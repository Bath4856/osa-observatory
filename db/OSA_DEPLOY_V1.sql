-- ============================================================
-- OSA / ISA OBSERVATORY
-- OSA_DEPLOY_V1.sql — SCRIPT MAÎTRE DE DÉPLOIEMENT
-- Version   : 1.0.0
-- Date      : 2026-03
-- ============================================================
-- ORDRE OBLIGATOIRE (dépendances FK inter-schémas) :
--   01_rf_schema.sql     → référentiel canonique (pillars, indicators, countries)
--   02_mm_schema.sql     → modèle métier (super_categories, categories, méthodes)
--   03_collect_schema.sql→ ingestion (providers, endpoints, raw_data partitionné)
--   04_ma_schema.sql     → analytique (pipeline L1→L7, ISA, vues matérialisées)
-- ============================================================
-- UTILISATION :
--   psql -U postgres -d osa_db -f OSA_DEPLOY_V1.sql
-- OU via \i dans psql :
--   \i 01_rf_schema.sql
--   \i 02_mm_schema.sql
--   \i 03_collect_schema.sql
--   \i 04_ma_schema.sql
-- ============================================================
-- PRÉ-REQUIS :
--   PostgreSQL 13+
--   Base de données vide créée : CREATE DATABASE osa_db;
--   Extension pgcrypto (optionnel, pour PKI Phase 4) :
--     CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- ============================================================

\echo '========================================================'
\echo 'OSA DEPLOY V1 — démarrage'
\echo '========================================================'

\echo ''
\echo '--- BLOC 01 : RF — Référentiel canonique ---'
\i 01_rf_schema.sql

\echo ''
\echo '--- BLOC 02 : MM — Modèle métier ---'
\i 02_mm_schema.sql

\echo ''
\echo '--- BLOC 03 : COLLECT — Ingestion ---'
\i 03_collect_schema.sql

\echo ''
\echo '--- BLOC 04 : MA — Analytique L1→L7 ---'
\i 04_ma_schema.sql

\echo ''
\echo '========================================================'
\echo 'Vérifications post-déploiement'
\echo '========================================================'

SELECT 'rf.pillars'             AS table_name, COUNT(*) AS rows FROM rf.pillars
UNION ALL
SELECT 'rf.indicators',                         COUNT(*) FROM rf.indicators
UNION ALL
SELECT 'rf.countries',                          COUNT(*) FROM rf.countries
UNION ALL
SELECT 'rf.units',                              COUNT(*) FROM rf.units
UNION ALL
SELECT 'mm.super_categories',                   COUNT(*) FROM mm.super_categories
UNION ALL
SELECT 'mm.categories',                         COUNT(*) FROM mm.categories
UNION ALL
SELECT 'mm.indicator_groups',                   COUNT(*) FROM mm.indicator_groups
UNION ALL
SELECT 'mm.indicator_group_links',              COUNT(*) FROM mm.indicator_group_links
UNION ALL
SELECT 'mm.source_origins',                     COUNT(*) FROM mm.source_origins
UNION ALL
SELECT 'collect.data_providers',                COUNT(*) FROM collect.data_providers
UNION ALL
SELECT 'collect.provider_endpoints',            COUNT(*) FROM collect.provider_endpoints
UNION ALL
SELECT 'collect.indicator_source',              COUNT(*) FROM collect.indicator_source
UNION ALL
SELECT 'ma.indicator_meta',                     COUNT(*) FROM ma.indicator_meta
UNION ALL
SELECT 'ma.indicator_meta_links',               COUNT(*) FROM ma.indicator_meta_links
UNION ALL
SELECT 'ma.indicator_method_versions',          COUNT(*) FROM ma.indicator_method_versions
ORDER BY table_name;

\echo ''
\echo 'Résultats attendus :'
\echo '  rf.pillars                  →  8'
\echo '  rf.indicators               →  120'
\echo '  rf.countries                →  54'
\echo '  rf.units                    →  16'
\echo '  mm.super_categories         →  26'
\echo '  mm.categories               →  ~64'
\echo '  mm.indicator_groups         →  8'
\echo '  mm.indicator_group_links    →  120'
\echo '  mm.source_origins           →  10'
\echo '  collect.data_providers      →  9'
\echo '  collect.provider_endpoints  →  8'
\echo '  collect.indicator_source    →  ~34'
\echo '  ma.indicator_meta           →  120'
\echo '  ma.indicator_meta_links     →  120'
\echo '  ma.indicator_method_versions→  6'
\echo ''
\echo '========================================================'
\echo 'OSA DEPLOY V1 — terminé'
\echo 'Prochaine étape : lancer les fetchers Python (sprint 2)'
\echo '========================================================'
