-- ============================================================
-- Sprint 26 — GAF Consolidation
-- Mise à jour finding #25 + création findings #26 et #27
-- Date : 23 juin 2026
-- Contexte : résultats de l'audit complet de la chaîne SWOT/P7I
--   et investigation des 24 cas STR_PENV confidence = 0
-- ============================================================
-- EXÉCUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint26_gaf_consolidated.sql
--
-- RÉSULTAT ATTENDU :
--   UPDATE 1        (finding #25 raw_finding enrichi)
--   INSERT 0 1      (finding #26 STR_CONFIDENCE_ENV_FOR_BUG)
--   INSERT 0 1      (finding #27 ENV_FOR_CORRECTION_PENDING)
--   + 3 SELECT de vérification
-- ============================================================

BEGIN;

-- ============================================================
-- 1. MISE À JOUR FINDING #25
--    Enrichissement du raw_finding avec les résultats réels
--    de l'exécution Lot A/B et l'investigation des 24 cas
-- ============================================================

UPDATE ops.audit_findings
SET
    raw_finding = raw_finding || '{
      "execution_results": {
        "lot_a_executed": "2026-06-23",
        "backfill_rows": 9665,
        "distribution": {
          "OBSERVED": 5507,
          "OBSERVED_pct": 56.98,
          "ESTIMATED": 4133,
          "ESTIMATED_pct": 42.76,
          "MISSING": 25,
          "MISSING_pct": 0.26
        },
        "null_residuels": 0,
        "partitions": 11,
        "lot_b_executed": "2026-06-23",
        "views_created": ["ops.v_data_availability_audit", "ops.v_wkn_missing_summary"]
      },
      "audit_findings_produced": {
        "critical_gap": {
          "count": 1,
          "detail": "WKN_PENV | SDN | 2024 — TRIGGER_EXCEPTIONAL actif, WKN absent"
        },
        "info_missing": {
          "count": 24,
          "indicator": "STR_PENV",
          "pattern": "confidence = 0 sur nb_forces = 1 (ENV_FOR seul)",
          "root_cause": "Bug unité ENV_FOR (1000 ha vs %) — voir finding #27"
        },
        "quality_note_estimated": {
          "count": 4133,
          "dominant_case": "AGO 2024 — 5 signaux ESTIMATED (THR_PENV, OPP_PMIN, STR_PTRA, STR_PRES, OPP_PMIL)"
        }
      },
      "investigation_trace": {
        "chain_audit_confirmed": "COALESCE dans v_isa_strategic_diagnostic_engine ligne base",
        "str_penv_root_cause": "Règle de garde intentionnelle du calcul STR : confidence = 0 quand nb_forces = 1 sur indicateur ENV_FOR aberrant (bug unité non corrigé au moment du calcul — 5 mai 2026)",
        "str_script_status": "Calcul exécuté directement en base le 2026-05-05, non commité — voir finding #26",
        "env_for_patch": "patch_sprint23_env_for_correction.sql — présent en local, non appliqué en production"
      }
    }'::jsonb,
    updated_at = NOW()
WHERE finding_id = 25
  AND finding_code = 'SWOT_SIGNAL_AVAILABILITY';

-- ============================================================
-- 2. FINDING #26 — STR_CONFIDENCE_ENV_FOR_BUG
--    Règle de garde confidence = 0 sur STR_PENV :
--    comportement intentionnel documenté mais script source
--    non commité dans le dépôt
-- ============================================================

INSERT INTO ops.audit_findings (
    audit_id,
    module,
    finding_code,
    finding_hash,
    severity,
    publication_impact,
    iprs_weight,
    object_type,
    object_code,
    description,
    raw_finding,
    status
) VALUES (
    'a592c23b-423e-401f-aee4-a73fddce1129',

    'P7F-STR',

    'STR_CONFIDENCE_ENV_FOR_BUG',

    '0b31cfbd39bea4d9f095685fb857be378cc590d87129a96976e1e3a1a91400d6',

    'MEDIUM',

    -- Impact publication : les 24 cas STR_PENV MISSING n'affectent
    -- pas les scores ISA publiés (STR non utilisé dans ISA final).
    -- Impact analytique sur GENECO et diagnostic P7F — conditionnel.
    'CONDITIONAL',

    0.00,

    'COMPUTED_INDICATOR',
    'ma.computed_values.STR_PENV',

    'GAF-P7F-STR-001 -- 24 cas STR_PENV avec confidence = 0 dans ma.computed_values. '
    || 'Cause racine : règle de garde intentionnelle du script de calcul STR_PENV '
    || '(exécuté directement en base le 2026-05-05, non commité). '
    || 'La règle écrit confidence = 0 quand nb_forces = 1 ET que l''unique force retenue '
    || 'est ENV_FOR avec valeur normalisée extrême (0.000 ou 1.000), '
    || 'signalant que la force repose sur une donnée aberrante (bug unité ENV_FOR, '
    || 'corrigé dans patch_sprint23_env_for_correction.sql non encore appliqué). '
    || 'Après application du patch ENV_FOR et recalcul STR, '
    || 'ces 24 cas devraient se résoudre. '
    || 'Déficit documentaire secondaire : script de calcul STR non versionnée.',

    '{
      "reference": "GAF-P7F-STR-001",
      "sprint": "Sprint 26",
      "detected_at": "2026-06-23",

      "affected_cases": {
        "count": 24,
        "indicator": "STR_PENV",
        "pattern": "nb_forces = 1, confidence = 0.000",
        "countries_sample": ["COG","COM","LBR","NER","NGA","SLE","SOM","SSD","STP","SYC","TCD","TUN"],
        "years": [2020, 2021, 2022, 2023, 2024]
      },

      "root_cause": {
        "type": "INTENTIONAL_GUARD_RULE",
        "description": "Le script de calcul STR applique confidence = 0 quand nb_forces = 1 sur indicateur ENV_FOR avec valeur normalisée extrême. La règle est correcte : elle signale une force fondée sur une seule donnée aberrante.",
        "env_for_bug": "ENV_FOR ingéré en 1000 ha (item 6646/element 5110) au lieu de % couverture (item 6646/element 7209). Valeurs jusqu''à 283340 au lieu de 0-100. Normalisées en 0.000 ou 1.000.",
        "calculation_date": "2026-05-05",
        "script_status": "Exécuté directement en base — non commité dans le dépôt GitHub"
      },

      "resolution_path": {
        "primary": "Appliquer patch_sprint23_env_for_correction.sql puis recalculer STR_PENV",
        "secondary": "Commiter le script de calcul STR/OPP dans le dépôt",
        "blocker": "Aucun — patch disponible en local"
      },

      "impact": {
        "isa_scores": "AUCUN — STR non utilisé dans le calcul ISA final",
        "geneco": "MINEUR — strength_score réduit dans v_isa_strategic_diagnostic_engine",
        "p7f_diagnostic": "24 cas classés MONITORING dans ops.v_data_availability_audit",
        "amar_triggers": "AUCUN — STR non utilisé par le moteur AMAR"
      },

      "distribution_nb_forces": {
        "nb_forces_1_confidence_0": 24,
        "nb_forces_1_confidence_gt_0": 72,
        "nb_forces_2_plus": 81
      }
    }'::jsonb,

    'ORIENTED'
)
RETURNING finding_id, finding_code, status;

-- ============================================================
-- 3. FINDING #27 — ENV_FOR_CORRECTION_PENDING
--    Patch correctif ENV_FOR disponible mais non appliqué
--    en production — impact en cascade sur STR_PENV et PENV
-- ============================================================

INSERT INTO ops.audit_findings (
    audit_id,
    module,
    finding_code,
    finding_hash,
    severity,
    publication_impact,
    iprs_weight,
    object_type,
    object_code,
    description,
    raw_finding,
    status
) VALUES (
    'a592c23b-423e-401f-aee4-a73fddce1129',

    'COLLECT-ENV',

    'ENV_FOR_CORRECTION_PENDING',

    'a4107cee824a5970c6242c07ba3817894f7e28cd32fb71c56feab2dd756a3c7e',

    -- HIGH : le bug d'unité ENV_FOR affecte les scores pilier PENV
    -- publiés 2020-2024. Le patch correctif existe mais n'est pas
    -- appliqué. Risque de résultats incorrects en publication.
    'HIGH',

    -- Les scores ISA PENV publiés 2020-2024 sont calculés sur
    -- des valeurs ENV_FOR aberrantes. Impact publication bloquant
    -- pour la qualité PENV — correction requise avant publication.
    'BLOCKING',

    -- Poids IPRS : PENV = 5% de l'ISA. Impact modéré sur score
    -- global mais potentiellement significatif pour PENV seul.
    0.05,

    'DATA_SOURCE',
    'collect.raw_data.ENV_FOR',

    'GAF-COLLECT-ENV-001 -- Bug d''unité ENV_FOR (couverture forestière FAO) : '
    || 'indicateur ingéré avec item 6646/element 5110 (1000 ha) '
    || 'au lieu de item 6646/element 7209 (% superficie couverte). '
    || 'Valeurs brutes jusqu''à 283 340 au lieu de 0–100. '
    || 'Patch correctif patch_sprint23_env_for_correction.sql disponible '
    || 'en local (147 observations réelles sur ancres FAO 2010/2015/2020, '
    || '49 pays). Non appliqué en production au 23 juin 2026. '
    || 'Impact en cascade : scores L3 ENV_FOR aberrants → '
    || 'normalisations erronées → STR_PENV confidence = 0 (24 cas) → '
    || 'scores PENV publiés potentiellement incorrects.',

    '{
      "reference": "GAF-COLLECT-ENV-001",
      "sprint": "Sprint 26",
      "detected_at": "2026-06-23",

      "bug_description": {
        "indicator": "ENV_FOR",
        "source": "FAO FRA (Forest Resources Assessment)",
        "wrong_element": "6646/5110 — Forest area in 1000 ha",
        "correct_element": "6646/7209 — Forest area as % of land area",
        "magnitude": "Valeurs jusqu''à 283340 (Angola) vs attendu ~56%",
        "affected_rows_l1": 692,
        "affected_countries": 49
      },

      "patch_available": {
        "filename": "patch_sprint23_env_for_correction.sql",
        "location": "db/patch_db/ (local) — absent du VPS",
        "content": "DELETE 692 lignes + INSERT 147 observations réelles (ancres FAO 2010/2015/2020)",
        "post_patch_steps": [
          "Relancer imputer_v3 pour ENV_FOR (interpolation 2011-2014, 2016-2019, forward-fill 2021-2024)",
          "Recalculer L3 ENV_FOR 2010-2024",
          "Recalculer SOV_PENV via compute_pillar_score / compute_isa",
          "Recalculer WKN_PENV, THR_PENV, STR_PENV, OPP_PENV",
          "Rafraîchir les vues matérialisées pub.mv_*"
        ],
        "expected_resolution": "24 cas STR_PENV MISSING résolus après recalcul"
      },

      "cascade_impact": {
        "l3_env_for": "Valeurs normalisées aberrantes (0.000 ou 1.000) sur les années non-ancre",
        "str_penv_confidence_0": "24 cas — règle de garde activée correctement sur données aberrantes",
        "penv_pillar_scores": "Scores PENV publiés 2020-2024 calculés sur ENV_FOR incorrect",
        "isa_global": "Impact partiel — ENV_FOR est un indicateur parmi ~14 sur PENV (poids 5%)",
        "amar_triggers": "AUCUN impact direct — AMAR utilise THR_PENV pas ENV_FOR directement"
      },

      "priority": {
        "urgency": "HAUTE — patch disponible, impact sur données publiées OFFICIAL",
        "blocking": "Non bloquant pour l''architecture — bloquant pour la qualité PENV",
        "recommended_sprint": "Sprint 26 ou Sprint 27 selon charge"
      }
    }'::jsonb,

    -- OPEN : décision d'application du patch non encore prise
    -- (nécessite validation Conseil technique — impact sur scores OFFICIAL publiés)
    'OPEN'
)
RETURNING finding_id, finding_code, status;

-- ============================================================
-- 4. VÉRIFICATIONS
-- ============================================================

-- 4.1 État des 3 findings liés à cette investigation
SELECT
    finding_id,
    finding_code,
    severity,
    publication_impact,
    status,
    detected_at::date AS date_finding
FROM ops.audit_findings
WHERE finding_id IN (25, 26, 27)
   OR finding_code IN (
       'SWOT_SIGNAL_AVAILABILITY',
       'STR_CONFIDENCE_ENV_FOR_BUG',
       'ENV_FOR_CORRECTION_PENDING'
   )
ORDER BY finding_id;

-- 4.2 Vue d'ensemble du GAF — tous findings actifs
SELECT
    finding_id,
    finding_code,
    severity,
    status,
    detected_at::date AS date
FROM ops.audit_findings
WHERE status NOT IN ('CLOSED', 'RESOLVED')
ORDER BY finding_id;

COMMIT;
