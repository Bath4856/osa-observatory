\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7E OBSERVED PUBLICATION ENGINE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 0. Colonnes source P7E — ma.indicator_values_final ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'indicator_values_final'
ORDER BY ordinal_position;

\echo ''
\echo '=== 0b. Colonnes source P7E — ma.v_dynamic_scores_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_dynamic_scores_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== 1. Politique de publication ISA ==='
SELECT policy_code, publication_status, is_public, is_official, publication_note
FROM rf.isa_publication_policy
ORDER BY policy_code;

\echo ''
\echo '=== 2. Volumétrie moteur observé ==='
SELECT
    COUNT(*) AS nb_observed_indicator_rows,
    COUNT(DISTINCT country_iso3) AS nb_countries,
    COUNT(DISTINCT year) AS nb_years,
    COUNT(DISTINCT pillar_code) AS nb_pillars,
    COUNT(DISTINCT indicator_code) AS nb_indicators
FROM ma.v_isa_observed_publication_engine;

\echo ''
\echo '=== 3. Statuts publication ==='
SELECT publication_status, publication_cycle, COUNT(*) AS nb
FROM ma.v_isa_observed_publication_engine
GROUP BY publication_status, publication_cycle
ORDER BY publication_status, publication_cycle;

\echo ''
\echo '=== 4. Scores observés par pilier — synthèse ==='
SELECT
    pillar_code,
    COUNT(*) AS nb_rows,
    ROUND(AVG(isa_observed_score)::NUMERIC, 3) AS avg_isa_observed_score,
    ROUND(AVG(sovereignty_observed_score)::NUMERIC, 3) AS avg_sovereignty_observed_score,
    ROUND(AVG(vulnerability_observed_score)::NUMERIC, 3) AS avg_vulnerability_observed_score,
    ROUND(AVG(data_completeness)::NUMERIC, 3) AS avg_data_completeness
FROM ma.v_isa_observed_scores_by_pillar
GROUP BY pillar_code
ORDER BY avg_isa_observed_score DESC NULLS LAST;

\echo ''
\echo '=== 5. Readiness publication ==='
SELECT *
FROM ma.v_isa_observed_publication_readiness
ORDER BY publication_status, publication_cycle;

\echo ''
\echo '=== 6. Top pays/année scores observés officiels/provisoires ==='
SELECT
    country_iso3,
    year,
    publication_status,
    nb_pillars_observed,
    data_completeness,
    isa_observed_score,
    sovereignty_observed_score,
    vulnerability_observed_score,
    publication_decision
FROM ma.v_isa_observed_scores_by_country_year
WHERE publication_status IN ('OFFICIAL_CONSOLIDATED','PROVISIONAL_N1')
ORDER BY year DESC, isa_observed_score DESC NULLS LAST
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7E TERMINÉ ==='
