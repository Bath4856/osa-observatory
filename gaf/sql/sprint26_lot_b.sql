-- ============================================================
-- Sprint 26 — Lot B
-- Vue de monitoring : ops.v_data_availability_audit
-- GAF-P7I-WKN-SEMANTICS-001 (finding_id = 25)
-- 23 juin 2026
-- ============================================================
-- PRÉREQUIS : Lot A exécuté et validé (colonne data_availability
-- présente et backfillée dans ma.computed_values).
--
-- EXÉCUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db < sprint26_lot_b.sql
--
-- SÉQUENCE :
--   Étape 1 — Vue ops.v_data_availability_audit
--   Étape 2 — Vue complémentaire ops.v_wkn_missing_summary
--   Étape 3 — Vérifications
-- ============================================================

BEGIN;

-- ============================================================
-- ÉTAPE 1 — Vue principale de monitoring
--
-- Objet : croiser les cas MISSING/ESTIMATED de ma.computed_values
-- avec les triggers actifs dans pub.amar_triggers.
--
-- Logique d'alerte :
--   CRITICAL_GAP : WKN MISSING sur pays portant un trigger
--     EXCEPTIONAL ou CRITICAL — combinaison la plus sensible :
--     le moteur AMAR a déclenché sans pouvoir évaluer WKN.
--   MONITORING   : WKN MISSING sans trigger actif — à surveiller.
--   QUALITY_NOTE : ESTIMATED (MICE) — signal présent mais incertain.
-- ============================================================

DROP VIEW IF EXISTS ops.v_data_availability_audit;

CREATE VIEW ops.v_data_availability_audit AS
WITH missing_signals AS (
    SELECT
        cv.indicator_code,
        cv.country_iso3,
        cv.year,
        cv.value,
        cv.confidence,
        cv.data_availability,
        cv.components,
        -- Type de signal SWOT (WKN / THR / STR / OPP / MON)
        LEFT(cv.indicator_code, 3)              AS swot_type,
        -- Pilier extrait du code (ex: WKN_PENV → PENV)
        SUBSTRING(cv.indicator_code FROM 5)     AS pillar_code
    FROM ma.computed_values cv
    WHERE cv.data_availability IN ('MISSING', 'ESTIMATED')
),
trigger_context AS (
    SELECT
        t.country_iso3,
        t.year,
        t.pillar_code,
        t.trigger_class,
        t.thr_score,
        t.wkn_score
    FROM pub.amar_triggers t
    WHERE t.trigger_class IN (
        'TRIGGER_EXCEPTIONAL',
        'TRIGGER_CRITICAL',
        'TRIGGER_ACTIVE',
        'TRIGGER_DIAGNOSTIC_INCOMPLETE'
    )
)
SELECT
    ms.indicator_code,
    ms.country_iso3,
    ms.year,
    ms.swot_type,
    ms.pillar_code,
    ms.data_availability,
    ms.value,
    ms.confidence,
    -- Trigger actif sur même pays / année / pilier
    tc.trigger_class                            AS active_trigger_class,
    tc.thr_score                                AS trigger_thr_score,
    tc.wkn_score                                AS trigger_wkn_score,
    -- Niveau d'alerte
    CASE
        WHEN ms.swot_type = 'WKN'
             AND ms.data_availability = 'MISSING'
             AND tc.trigger_class IN ('TRIGGER_EXCEPTIONAL', 'TRIGGER_CRITICAL')
        THEN 'CRITICAL_GAP'
        WHEN ms.swot_type = 'WKN'
             AND ms.data_availability = 'MISSING'
             AND tc.trigger_class IS NOT NULL
        THEN 'MONITORING'
        WHEN ms.swot_type = 'WKN'
             AND ms.data_availability = 'MISSING'
             AND tc.trigger_class IS NULL
        THEN 'MONITORING'
        WHEN ms.data_availability = 'ESTIMATED'
        THEN 'QUALITY_NOTE'
        ELSE 'INFO'
    END                                         AS alert_level,
    -- Contexte publication
    pp.status                                   AS publication_status
FROM missing_signals ms
LEFT JOIN trigger_context tc
    ON  tc.country_iso3 = ms.country_iso3
    AND tc.year         = ms.year
    AND tc.pillar_code  = ms.pillar_code
LEFT JOIN rf.publication_policy pp
    ON pp.year = ms.year
ORDER BY
    CASE
        WHEN ms.swot_type = 'WKN'
             AND ms.data_availability = 'MISSING'
             AND tc.trigger_class IN ('TRIGGER_EXCEPTIONAL','TRIGGER_CRITICAL')
        THEN 1
        WHEN ms.swot_type = 'WKN'
             AND ms.data_availability = 'MISSING'
        THEN 2
        WHEN ms.data_availability = 'ESTIMATED'
        THEN 3
        ELSE 4
    END,
    ms.year DESC,
    ms.country_iso3,
    ms.indicator_code;

COMMENT ON VIEW ops.v_data_availability_audit IS
    'Vue de monitoring de la disponibilité des signaux SWOT. '
    'Croise les cas MISSING/ESTIMATED de ma.computed_values '
    'avec les triggers actifs de pub.amar_triggers. '
    'alert_level : CRITICAL_GAP = WKN manquant sur trigger EXCEPTIONAL/CRITICAL ; '
    'MONITORING = WKN manquant sans trigger critique ; '
    'QUALITY_NOTE = valeur MICE (ESTIMATED). '
    'Ref : GAF-P7I-WKN-SEMANTICS-001 (ops.audit_findings finding_id = 25). '
    'Sprint 26 — 23 juin 2026.';

-- ============================================================
-- ÉTAPE 2 — Vue de synthèse par pays/année
-- Utile pour les rapports scientifiques et les audits Comité.
-- ============================================================

DROP VIEW IF EXISTS ops.v_wkn_missing_summary;

CREATE VIEW ops.v_wkn_missing_summary AS
SELECT
    cv.country_iso3,
    cv.year,
    COUNT(*) FILTER (
        WHERE cv.indicator_code LIKE 'WKN_%'
          AND cv.data_availability = 'MISSING'
    )                                           AS wkn_missing_count,
    COUNT(*) FILTER (
        WHERE cv.indicator_code LIKE 'WKN_%'
          AND cv.data_availability = 'OBSERVED'
    )                                           AS wkn_observed_count,
    COUNT(*) FILTER (
        WHERE cv.indicator_code LIKE 'WKN_%'
          AND cv.data_availability = 'ESTIMATED'
    )                                           AS wkn_estimated_count,
    -- Piliers WKN manquants (tableau)
    ARRAY_AGG(
        SUBSTRING(cv.indicator_code FROM 5)
        ORDER BY cv.indicator_code
    ) FILTER (
        WHERE cv.indicator_code LIKE 'WKN_%'
          AND cv.data_availability = 'MISSING'
    )                                           AS wkn_missing_pillars,
    -- Trigger le plus sévère sur ce pays/année
    MAX(t.trigger_class)                        AS worst_trigger_class,
    pp.status                                   AS publication_status
FROM ma.computed_values cv
LEFT JOIN pub.amar_triggers t
    ON  t.country_iso3 = cv.country_iso3
    AND t.year         = cv.year
LEFT JOIN rf.publication_policy pp
    ON pp.year = cv.year
WHERE cv.indicator_code LIKE 'WKN_%'
GROUP BY cv.country_iso3, cv.year, pp.status
HAVING COUNT(*) FILTER (
    WHERE cv.indicator_code LIKE 'WKN_%'
      AND cv.data_availability = 'MISSING'
) > 0
ORDER BY cv.year DESC, cv.country_iso3;

COMMENT ON VIEW ops.v_wkn_missing_summary IS
    'Synthèse par pays/année des piliers WKN manquants. '
    'Inclut le pire trigger actif pour contextualiser la criticité. '
    'Usage : rapports Comité Scientifique, audits qualité données. '
    'Ref : GAF-P7I-WKN-SEMANTICS-001. Sprint 26 — 23 juin 2026.';

-- ============================================================
-- ÉTAPE 3 — VÉRIFICATIONS
-- ============================================================

-- 3.1 Vue audit — résultat attendu : SDN 2024 WKN_PENV en CRITICAL_GAP
SELECT
    indicator_code,
    country_iso3,
    year,
    data_availability,
    active_trigger_class,
    alert_level,
    publication_status
FROM ops.v_data_availability_audit
ORDER BY alert_level, year DESC, country_iso3
LIMIT 30;

-- 3.2 Compte par alert_level
SELECT
    alert_level,
    COUNT(*) AS nb
FROM ops.v_data_availability_audit
GROUP BY alert_level
ORDER BY alert_level;

-- 3.3 Vue synthèse WKN missing
SELECT *
FROM ops.v_wkn_missing_summary
ORDER BY year DESC, country_iso3;

-- 3.4 Cas SDN 2024 isolé — vérification croisée
SELECT
    v.indicator_code,
    v.country_iso3,
    v.year,
    v.data_availability,
    v.active_trigger_class,
    v.trigger_thr_score,
    v.trigger_wkn_score,
    v.alert_level
FROM ops.v_data_availability_audit v
WHERE v.country_iso3 = 'SDN'
  AND v.year = 2024;

COMMIT;
