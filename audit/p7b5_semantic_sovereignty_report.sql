\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7B5 SEMANTIC SOVEREIGNTY ENGINE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Politique de souveraineté sémantique ==='
SELECT
    semantic_code,
    sovereignty_role,
    base_sovereignty_weight,
    sovereignty_floor,
    sovereignty_ceiling,
    dependency_penalty,
    locked_review_penalty,
    forecast_disabled_penalty
FROM rf.semantic_sovereignty_policy
ORDER BY base_sovereignty_weight DESC, semantic_code;

\echo ''
\echo '=== 2. Classes de souveraineté P7B5 ==='
SELECT
    semantic_sovereignty_class,
    COUNT(*) AS nb
FROM ma.v_semantic_sovereignty_engine
GROUP BY semantic_sovereignty_class
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Décisions ISA souveraineté ==='
SELECT
    isa_sovereignty_decision,
    COUNT(*) AS nb
FROM ma.v_semantic_sovereignty_engine
GROUP BY isa_sovereignty_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Souveraineté par pilier ==='
SELECT
    pillar_code,
    COUNT(*) AS nb,
    ROUND(AVG(semantic_sovereignty_score), 3) AS avg_sovereignty,
    ROUND(AVG(semantic_sovereignty_vulnerability), 3) AS avg_vulnerability,
    COUNT(*) FILTER (WHERE semantic_sovereignty_class = 'SOVEREIGNTY_GAP_LOCKED') AS nb_locked
FROM ma.v_semantic_sovereignty_engine
GROUP BY pillar_code
ORDER BY avg_sovereignty;

\echo ''
\echo '=== 5. Readiness souveraineté par pilier/famille ==='
SELECT
    pillar_code,
    semantic_code,
    nb_indicators,
    avg_sovereignty_score,
    avg_sovereignty_vulnerability,
    avg_dynamic_confidence,
    avg_operational_score,
    avg_forecastability_score,
    nb_sovereignty_strong,
    nb_sovereignty_controlled,
    nb_sovereignty_fragile,
    nb_sovereignty_gap_locked,
    isa_sovereignty_readiness_score,
    sovereignty_readiness_status
FROM ma.v_isa_sovereignty_readiness
ORDER BY
    CASE
        WHEN sovereignty_readiness_status = 'NEEDS_SOVEREIGNTY_REVIEW' THEN 0
        WHEN sovereignty_readiness_status = 'SOVEREIGNTY_WEAK' THEN 1
        WHEN sovereignty_readiness_status = 'SOVEREIGNTY_CONTEXTUAL' THEN 2
        WHEN sovereignty_readiness_status = 'SOVEREIGNTY_READY_CONTROLLED' THEN 3
        ELSE 4
    END,
    avg_sovereignty_score;

\echo ''
\echo '=== 6. Top signaux souveraineté faibles / verrouillés ==='
SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,
    semantic_sovereignty_score,
    semantic_sovereignty_vulnerability,
    semantic_sovereignty_class,
    isa_sovereignty_decision,
    sovereignty_reason,
    semantic_operational_status,
    semantic_forecast_status
FROM ma.v_semantic_sovereignty_engine
WHERE semantic_sovereignty_class IN (
    'SOVEREIGNTY_GAP_LOCKED',
    'SOVEREIGNTY_WEAK_SIGNAL',
    'SOVEREIGNTY_FRAGILE_BUT_INFORMATIVE'
)
ORDER BY
    CASE
        WHEN semantic_sovereignty_class = 'SOVEREIGNTY_GAP_LOCKED' THEN 0
        WHEN semantic_sovereignty_class = 'SOVEREIGNTY_WEAK_SIGNAL' THEN 1
        ELSE 2
    END,
    semantic_sovereignty_score,
    pillar_code,
    indicator_code
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7B5 TERMINÉ ==='
