-- ============================================================
-- OSA / ISA OBSERVATORY 20260407
-- patch_unpk_milcyb_providers.sql
-- ============================================================
-- 1. Enregistre UNPK (IPI Peacekeeping) comme nouveau provider
-- 2. Ajoute MIL_CYB dans source_registry_indicators (ITU)
-- 3. Ajoute MIL_MIS et GEO_PEA (UNPK)
-- ============================================================

BEGIN;

-- ── 1. Nouveau provider UNPK ──────────────────────────────
INSERT INTO collect.source_registry (
    source_id, name, organization, api_type, base_url,
    status, priority,
    coverage, stability, limits, reason,
    freshness_score, completeness_score, reliability_score,
    is_active
)
VALUES (
    'UNPK',
    'IPI Peacekeeping Database',
    'International Peace Institute / Humanitarian Data Exchange',
    'CSV_BULK',
    'https://data.humdata.org/dataset/ipi-peacekeeping-database',
    'PILOT',
    4,
    'Pays africains contributeurs ONU — 1990-2018',
    'MEDIUM',
    'Données jusqu''en 2018 uniquement — pas de mise à jour récente',
    'Série historique fiable, arrêtée en 2018',
    0.75, 0.70, 0.85,
    TRUE
)
ON CONFLICT (source_id) DO UPDATE SET
    name               = EXCLUDED.name,
    organization       = EXCLUDED.organization,
    api_type           = EXCLUDED.api_type,
    base_url           = EXCLUDED.base_url,
    status             = EXCLUDED.status,
    priority           = EXCLUDED.priority,
    coverage           = EXCLUDED.coverage,
    stability          = EXCLUDED.stability,
    limits             = EXCLUDED.limits,
    reason             = EXCLUDED.reason,
    freshness_score    = EXCLUDED.freshness_score,
    completeness_score = EXCLUDED.completeness_score,
    reliability_score  = EXCLUDED.reliability_score,
    is_active          = TRUE,
    updated_at         = now();

-- ── 2. MIL_CYB → ITU (alias GCI, même source que NUM_CYB) ─
INSERT INTO collect.source_registry_indicators (
    source_id, osa_code, source_code, endpoint,
    fallback, unit, frequency, decision, is_active
)
VALUES (
    'ITU',
    'MIL_CYB',
    'GCI',
    'https://datahub.itu.int/api/data/',
    NULL,
    'SCORE_0_100',
    'periodic',
    'GO',
    TRUE
)
ON CONFLICT (source_id, source_code) DO NOTHING;

-- ── 3. Indicateurs UNPK ───────────────────────────────────
INSERT INTO collect.source_registry_indicators (
    source_id, osa_code, source_code, endpoint,
    fallback, unit, frequency, decision, is_active
)
VALUES
(
    'UNPK',
    'MIL_MIS',
    'total_troops',
    'https://data.humdata.org/dataset/ipi-peacekeeping-database',
    NULL,
    'PERSONS',
    'annual',
    'PILOT',
    TRUE
),
(
    'UNPK',
    'GEO_PEA',
    'total_personnel',
    'https://data.humdata.org/dataset/ipi-peacekeeping-database',
    NULL,
    'PERSONS',
    'annual',
    'PILOT',
    TRUE
)
ON CONFLICT (source_id, source_code) DO UPDATE SET
    osa_code   = EXCLUDED.osa_code,
    endpoint   = EXCLUDED.endpoint,
    decision   = EXCLUDED.decision,
    is_active  = TRUE,
    updated_at = now();

-- ── Vérification ──────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.source_registry
    WHERE source_id IN ('ITU', 'UNPK');
    RAISE NOTICE 'Providers ITU+UNPK : %', v_count;

    SELECT COUNT(*) INTO v_count
    FROM collect.source_registry_indicators
    WHERE (source_id = 'ITU'  AND osa_code = 'MIL_CYB')
       OR (source_id = 'UNPK' AND osa_code IN ('MIL_MIS', 'GEO_PEA'));
    RAISE NOTICE 'Indicateurs MIL_CYB+MIL_MIS+GEO_PEA : % (attendu 3)', v_count;
END;
$$;

COMMIT;
