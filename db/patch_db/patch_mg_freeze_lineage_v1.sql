-- =============================================================================
-- OSA / ISA — PATCH MG FREEZE & LINEAGE V1
-- Version : MG_V1
--
-- BLOC 1 — Freeze P7K V3
--   mg.isa_package_freeze_registry   : état de gel des packages
--   Mise à jour rf.package_lifecycle : P7K → FROZEN
--
-- BLOC 2 — Lineage MG
--   mg.isa_view_lineage_registry     : dépendances entre objets MA/RF/MG
--   mg.v_lineage_dependency_chain    : vue de navigation des chaînes
--   mg.v_lineage_refresh_order       : ordre de recalcul sûr
--   mg.v_lineage_cascade_risk        : objets à risque DROP CASCADE
--
-- Principe :
--   MG porte la gouvernance institutionnelle des modèles.
--   Freeze = garantie d'intégrité de baseline.
--   Lineage = traçabilité des dépendances pour recalculs contrôlés.
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS mg;

-- =============================================================================
-- BLOC 1 — FREEZE P7K V3
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 mg.isa_package_freeze_registry
--     Registre de gel des packages OSA
--     Un package FROZEN ne peut être modifié qu'après UNFREEZE explicite
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS mg.isa_package_freeze_registry CASCADE;

CREATE TABLE mg.isa_package_freeze_registry (
    package_code            TEXT            NOT NULL,
    package_version         TEXT            NOT NULL,
    freeze_status           TEXT            NOT NULL
                                CHECK (freeze_status IN
                                    ('FROZEN','UNFROZEN','DEPRECATED')),
    freeze_date             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    unfrozen_date           TIMESTAMPTZ,
    frozen_by               TEXT            NOT NULL DEFAULT 'SYSTEM',
    freeze_note             TEXT            NOT NULL,
    -- Snapshot des métriques clés au moment du freeze
    snapshot_rows           INTEGER,
    snapshot_countries      INTEGER,
    snapshot_years          INTEGER,
    snapshot_pillars        INTEGER,
    snapshot_audit_status   TEXT,

    PRIMARY KEY (package_code, package_version)
);

COMMENT ON TABLE mg.isa_package_freeze_registry IS
    'Registre de gel des packages OSA/ISA.
     FROZEN     : baseline stabilisée — modifications interdites sans UNFREEZE.
     UNFROZEN   : gel levé — modifications autorisées.
     DEPRECATED : package remplacé par une version ultérieure.
     Schéma MG : gouvernance institutionnelle des packages.';

COMMENT ON COLUMN mg.isa_package_freeze_registry.snapshot_rows IS
    'Nombre de lignes dans la MV principale au moment du freeze.
     Sert de référence pour détecter une dérive post-freeze.';

-- -----------------------------------------------------------------------------
-- 1.2 Freeze P7K V3 — insertion avec snapshot
-- -----------------------------------------------------------------------------
INSERT INTO mg.isa_package_freeze_registry (
    package_code, package_version, freeze_status,
    freeze_date, frozen_by, freeze_note,
    snapshot_rows, snapshot_countries, snapshot_years,
    snapshot_pillars, snapshot_audit_status
)
SELECT
    'P7K', 'V3', 'FROZEN',
    NOW(), 'SYSTEM',
    'P7K metrological calibration layer V3 stabilized. '
    || 'Includes: rf.isa_executive_cost_model (10 families, PROVISIONAL, uncertainty 0.15-0.25), '
    || 'mg.isa_model_governance_policy (3 statuses), '
    || 'ma.mv_isa_executive_master_board (predictive_execution_status, predictive_gap_score), '
    || 'rf.isa_cost_model_audit_log + trigger trg_cost_model_audit. '
    || 'min_predictive_gap=0.050 (PRES). All checks AUDIT_OK.',
    COUNT(*),
    COUNT(DISTINCT country_iso3),
    COUNT(DISTINCT year),
    COUNT(DISTINCT pillar_code),
    'AUDIT_OK'
FROM ma.mv_isa_executive_master_board;

-- -----------------------------------------------------------------------------
-- 1.3 Mettre à jour rf.package_lifecycle : P7K → statut freeze
-- -----------------------------------------------------------------------------
UPDATE rf.package_lifecycle
SET
    package_status  = 'FROZEN',
    notes           = COALESCE(notes, '') ||
                      ' | FROZEN V3 ' || TO_CHAR(NOW(), 'YYYY-MM-DD') ||
                      ' : metrological calibration layer stabilized.',
    updated_at      = NOW()
WHERE package_code = 'P7K';

-- -----------------------------------------------------------------------------
-- 1.4 Validation freeze
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_freeze    INTEGER;
    v_lifecycle INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_freeze
        FROM mg.isa_package_freeze_registry
        WHERE package_code = 'P7K'
          AND package_version = 'V3'
          AND freeze_status = 'FROZEN';

    SELECT COUNT(*) INTO v_lifecycle
        FROM rf.package_lifecycle
        WHERE package_code = 'P7K'
          AND package_status = 'FROZEN';

    RAISE NOTICE 'P7K freeze : freeze_registry=%, lifecycle_frozen=%',
        v_freeze, v_lifecycle;

    IF v_freeze = 0 THEN
        RAISE EXCEPTION 'ABORT : P7K V3 non enregistré dans freeze_registry';
    END IF;
    IF v_lifecycle = 0 THEN
        RAISE EXCEPTION 'ABORT : rf.package_lifecycle P7K non mis à jour FROZEN';
    END IF;
END $$;

-- =============================================================================
-- BLOC 2 — LINEAGE MG
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 mg.isa_view_lineage_registry
--     Registre des dépendances entre objets MA/RF/MG
--     Chaque ligne = une dépendance directe entre deux objets
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS mg.isa_view_lineage_registry CASCADE;

CREATE TABLE mg.isa_view_lineage_registry (
    lineage_id              SERIAL          PRIMARY KEY,
    -- Objet source (celui qui dépend)
    source_schema           TEXT            NOT NULL,
    source_object           TEXT            NOT NULL,
    source_object_type      TEXT            NOT NULL
                                CHECK (source_object_type IN
                                    ('VIEW','MATERIALIZED_VIEW','TABLE',
                                     'FUNCTION','TRIGGER')),
    -- Objet cible (celui dont on dépend)
    target_schema           TEXT            NOT NULL,
    target_object           TEXT            NOT NULL,
    target_object_type      TEXT            NOT NULL
                                CHECK (target_object_type IN
                                    ('VIEW','MATERIALIZED_VIEW','TABLE',
                                     'FUNCTION','TRIGGER')),
    -- Métadonnées de dépendance
    dependency_type         TEXT            NOT NULL
                                CHECK (dependency_type IN
                                    ('DIRECT_READ',    -- SELECT depuis
                                     'JOIN',           -- JOIN sur
                                     'CASCADE_DROP',   -- DROP cascade
                                     'REFRESH_TRIGGER',-- REFRESH déclenche
                                     'POLICY_READ')),  -- lit une politique
    cascade_risk            TEXT            NOT NULL
                                CHECK (cascade_risk IN
                                    ('HIGH',    -- DROP cible → DROP source
                                     'MEDIUM',  -- DROP cible → erreur source
                                     'LOW')),   -- DROP cible → pas d'impact
    refresh_order           INTEGER         NOT NULL
                                CHECK (refresh_order BETWEEN 1 AND 99),
    package_code            TEXT            NOT NULL,
    lineage_note            TEXT,
    registered_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE mg.isa_view_lineage_registry IS
    'Registre des dépendances entre objets MA/RF/MG.
     Permet de déterminer l''ordre sûr de recalcul et d''identifier
     les objets à risque CASCADE avant tout DROP.
     refresh_order : ordre croissant = ordre de recréation sûr.
     cascade_risk HIGH : un DROP sur target entraîne un DROP CASCADE sur source.';

CREATE INDEX idx_lineage_source
    ON mg.isa_view_lineage_registry (source_schema, source_object);
CREATE INDEX idx_lineage_target
    ON mg.isa_view_lineage_registry (target_schema, target_object);
CREATE INDEX idx_lineage_package
    ON mg.isa_view_lineage_registry (package_code);
CREATE INDEX idx_lineage_cascade_risk
    ON mg.isa_view_lineage_registry (cascade_risk);
CREATE INDEX idx_lineage_refresh_order
    ON mg.isa_view_lineage_registry (refresh_order);

-- -----------------------------------------------------------------------------
-- 2.2 Insertion du lineage P7K V3
--     Couvre : RF → MG → MA (MV + vues)
--     refresh_order = ordre de recréation sûr après DROP
-- -----------------------------------------------------------------------------
INSERT INTO mg.isa_view_lineage_registry (
    source_schema, source_object, source_object_type,
    target_schema, target_object, target_object_type,
    dependency_type, cascade_risk, refresh_order,
    package_code, lineage_note
) VALUES

-- -----------------------------------------------------------------------
-- Niveau 1 — Tables RF de base (refresh_order 1-9)
-- -----------------------------------------------------------------------
('rf', 'isa_executive_cost_model',      'TABLE',
 'rf', 'isa_intervention_family_registry', 'TABLE',
 'DIRECT_READ', 'LOW', 1, 'P7K',
 'Cost model référence les familles d''intervention'),

('mg', 'isa_model_governance_policy',   'TABLE',
 'rf', 'isa_executive_cost_model',      'TABLE',
 'POLICY_READ', 'LOW', 2, 'P7K',
 'Politique MG lit calibration_status de RF'),

-- -----------------------------------------------------------------------
-- Niveau 2 — Sources P7K (refresh_order 10-19)
-- -----------------------------------------------------------------------
('ma', 'v_p7k_executive_source',        'VIEW',
 'ma', 'v_isa_intervention_decision_matrix', 'VIEW',
 'DIRECT_READ', 'HIGH', 10, 'P7K',
 'Source P7K lit la matrice de décision P7J'),

('ma', 'v_p7k_executive_source',        'VIEW',
 'ma', 'v_isa_decision_country_year',   'VIEW',
 'DIRECT_READ', 'HIGH', 10, 'P7K',
 'Source P7K lit les décisions pays/année'),

-- -----------------------------------------------------------------------
-- Niveau 3 — Portfolio exécutif (refresh_order 20-29)
-- -----------------------------------------------------------------------
('ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'ma', 'v_p7k_executive_source',        'VIEW',
 'DIRECT_READ', 'HIGH', 20, 'P7K',
 'Portfolio lit la source P7K'),

('ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'rf', 'isa_executive_governance_policy', 'TABLE',
 'POLICY_READ', 'MEDIUM', 20, 'P7K',
 'Portfolio lit la politique de gouvernance exécutive'),

('ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'rf', 'isa_executive_escalation_policy', 'TABLE',
 'POLICY_READ', 'MEDIUM', 20, 'P7K',
 'Portfolio lit la politique d''escalade'),

-- -----------------------------------------------------------------------
-- Niveau 4 — MV master board (refresh_order 30)
--            CRITIQUE : DROP cascade sur toutes les vues dépendantes
-- -----------------------------------------------------------------------
('ma', 'mv_isa_executive_master_board', 'MATERIALIZED_VIEW',
 'ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'DIRECT_READ', 'HIGH', 30, 'P7K',
 'MV lit le portfolio exécutif — DROP MV = CASCADE sur 3 vues dépendantes'),

('ma', 'mv_isa_executive_master_board', 'MATERIALIZED_VIEW',
 'ma', 'v_isa_decision_country_year',   'VIEW',
 'JOIN', 'HIGH', 30, 'P7K',
 'MV joint les décisions pays/année'),

('ma', 'mv_isa_executive_master_board', 'MATERIALIZED_VIEW',
 'rf', 'isa_executive_cost_model',      'TABLE',
 'JOIN', 'HIGH', 30, 'P7K',
 'MV joint le cost model RF — DROP TABLE = erreur MV'),

('ma', 'mv_isa_executive_master_board', 'MATERIALIZED_VIEW',
 'mg', 'isa_model_governance_policy',   'TABLE',
 'POLICY_READ', 'MEDIUM', 30, 'P7K',
 'MV lit la politique MG pour predictive_execution_status'),

-- -----------------------------------------------------------------------
-- Niveau 5 — Vues dépendantes de la MV (refresh_order 40-49)
--            CASCADE_DROP : DROP MV entraîne DROP de ces vues
-- -----------------------------------------------------------------------
('ma', 'v_isa_executive_cost_projection', 'VIEW',
 'ma', 'mv_isa_executive_master_board', 'MATERIALIZED_VIEW',
 'CASCADE_DROP', 'HIGH', 40, 'P7K',
 'Droppée par CASCADE si DROP MV — à recréer en ordre 40'),

('ma', 'v_isa_executive_master_board',  'VIEW',
 'ma', 'mv_isa_executive_master_board', 'MATERIALIZED_VIEW',
 'CASCADE_DROP', 'HIGH', 40, 'P7K',
 'Droppée par CASCADE si DROP MV — à recréer en ordre 40'),

-- -----------------------------------------------------------------------
-- Niveau 6 — Vues dépendantes des vues de niveau 5 (refresh_order 50-59)
-- -----------------------------------------------------------------------
('ma', 'v_isa_predictive_readiness_registry', 'VIEW',
 'ma', 'v_isa_executive_master_board',  'VIEW',
 'CASCADE_DROP', 'HIGH', 50, 'P7K',
 'Droppée par CASCADE si DROP v_isa_executive_master_board'),

('ma', 'v_isa_budget_arbitration_matrix', 'VIEW',
 'ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'DIRECT_READ', 'HIGH', 40, 'P7K',
 'Budget arbitration lit le portfolio'),

('ma', 'v_isa_board_decision_pack',     'VIEW',
 'ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'DIRECT_READ', 'HIGH', 40, 'P7K',
 'Board pack lit le portfolio'),

('ma', 'v_isa_governance_heatmap',      'VIEW',
 'ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'DIRECT_READ', 'HIGH', 40, 'P7K',
 'Heatmap lit le portfolio'),

('ma', 'v_isa_executive_watchlist',     'VIEW',
 'ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'DIRECT_READ', 'HIGH', 40, 'P7K',
 'Watchlist lit le portfolio'),

('ma', 'v_isa_national_escalation_queue', 'VIEW',
 'ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'DIRECT_READ', 'HIGH', 40, 'P7K',
 'Escalation queue lit le portfolio'),

('ma', 'v_isa_executive_governance_readiness', 'VIEW',
 'ma', 'v_isa_executive_priority_portfolio', 'VIEW',
 'DIRECT_READ', 'HIGH', 40, 'P7K',
 'Readiness lit le portfolio'),

-- -----------------------------------------------------------------------
-- Trigger RF (refresh_order 5)
-- -----------------------------------------------------------------------
('rf', 'trg_cost_model_audit',          'TRIGGER',
 'rf', 'isa_executive_cost_model',      'TABLE',
 'REFRESH_TRIGGER', 'LOW', 5, 'P7K',
 'Trigger audit attaché sur isa_executive_cost_model — '
 'toute UPDATE logue dans isa_cost_model_audit_log'),

-- -----------------------------------------------------------------------
-- Vue MG review_due (refresh_order 3)
-- -----------------------------------------------------------------------
('mg', 'v_cost_model_review_due',       'VIEW',
 'rf', 'isa_executive_cost_model',      'TABLE',
 'DIRECT_READ', 'MEDIUM', 3, 'P7K',
 'Vue MG lit RF pour détecter révisions en retard');

-- -----------------------------------------------------------------------------
-- 2.3 mg.v_lineage_dependency_chain
--     Navigation des chaînes de dépendance pour un objet donné
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS mg.v_lineage_dependency_chain;

CREATE VIEW mg.v_lineage_dependency_chain AS
SELECT
    l.refresh_order,
    l.source_schema || '.' || l.source_object   AS source_object_full,
    l.source_object_type,
    l.dependency_type,
    l.cascade_risk,
    l.target_schema || '.' || l.target_object   AS target_object_full,
    l.target_object_type,
    l.package_code,
    l.lineage_note
FROM mg.isa_view_lineage_registry l
ORDER BY l.refresh_order, l.source_schema, l.source_object;

COMMENT ON VIEW mg.v_lineage_dependency_chain IS
    'Navigation complète des chaînes de dépendance P7K.
     Triée par refresh_order : ordre croissant = ordre de recréation sûr.
     Filtrer sur cascade_risk=HIGH pour identifier les objets à risque DROP.';

-- -----------------------------------------------------------------------------
-- 2.4 mg.v_lineage_refresh_order
--     Ordre de recalcul sûr — à suivre lors de tout REFRESH ou DROP
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS mg.v_lineage_refresh_order;

CREATE VIEW mg.v_lineage_refresh_order AS
SELECT
    agg.refresh_order,
    agg.schema_name,
    agg.object_name,
    agg.object_type,
    agg.package_code,
    agg.nb_dependencies,
    agg.depends_on
FROM (
    SELECT
        MIN(l.refresh_order)                        AS refresh_order,
        l.source_schema                             AS schema_name,
        l.source_object                             AS object_name,
        MIN(l.source_object_type)                   AS object_type,
        MIN(l.package_code)                         AS package_code,
        COUNT(*)                                    AS nb_dependencies,
        STRING_AGG(
            l.target_schema || '.' || l.target_object,
            ', ' ORDER BY l.target_object
        )                                           AS depends_on
    FROM mg.isa_view_lineage_registry l
    GROUP BY l.source_schema, l.source_object
) agg
ORDER BY agg.refresh_order, agg.schema_name, agg.object_name;

COMMENT ON VIEW mg.v_lineage_refresh_order IS
    'Ordre de recréation sûr de tous les objets P7K.
     Utiliser cet ordre lors de tout DROP/RECREATE ou REFRESH de MV.
     nb_dependencies : nombre de tables/vues dont dépend cet objet.
     depends_on : liste des dépendances directes.';

-- -----------------------------------------------------------------------------
-- 2.5 mg.v_lineage_cascade_risk
--     Objets à risque HIGH — à vérifier avant tout DROP
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS mg.v_lineage_cascade_risk;

CREATE VIEW mg.v_lineage_cascade_risk AS
SELECT
    l.target_schema || '.' || l.target_object   AS at_risk_object,
    l.target_object_type,
    COUNT(*)                                    AS nb_dependents,
    STRING_AGG(
        l.source_schema || '.' || l.source_object,
        ', ' ORDER BY l.refresh_order, l.source_object
    )                                           AS dependent_objects,
    MAX(l.refresh_order)                        AS max_refresh_order,
    l.package_code
FROM mg.isa_view_lineage_registry l
WHERE l.cascade_risk = 'HIGH'
GROUP BY l.target_schema, l.target_object,
         l.target_object_type, l.package_code
ORDER BY nb_dependents DESC, at_risk_object;

COMMENT ON VIEW mg.v_lineage_cascade_risk IS
    'Objets dont le DROP entraîne un CASCADE sur d''autres objets.
     Toujours consulter cette vue avant un DROP sur un objet P7K.
     nb_dependents : nombre d''objets qui seront droppés en cascade.
     dependent_objects : liste complète des victimes du CASCADE.';

-- -----------------------------------------------------------------------------
-- 2.6 Validation lineage
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_lineage_rows  INTEGER;
    v_high_risk     INTEGER;
    v_mv_lineage    INTEGER;
    v_views         INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_lineage_rows
        FROM mg.isa_view_lineage_registry;
    SELECT COUNT(DISTINCT target_schema || '.' || target_object)
        INTO v_high_risk
        FROM mg.isa_view_lineage_registry
        WHERE cascade_risk = 'HIGH';
    SELECT COUNT(*) INTO v_mv_lineage
        FROM mg.isa_view_lineage_registry
        WHERE source_object = 'mv_isa_executive_master_board';
    SELECT COUNT(*) INTO v_views
        FROM information_schema.views
        WHERE table_schema = 'mg'
          AND table_name IN (
              'v_lineage_dependency_chain',
              'v_lineage_refresh_order',
              'v_lineage_cascade_risk');

    RAISE NOTICE
        'MG lineage V1 : lineage_rows=%, high_risk_objects=%, '
        'mv_dependencies=%, mg_views=%',
        v_lineage_rows, v_high_risk, v_mv_lineage, v_views;

    IF v_lineage_rows = 0 THEN
        RAISE EXCEPTION 'ABORT : isa_view_lineage_registry vide';
    END IF;
    IF v_views <> 3 THEN
        RAISE EXCEPTION 'ABORT : vues MG manquantes (attendu 3, obtenu %)',
            v_views;
    END IF;
END $$;

COMMIT;


