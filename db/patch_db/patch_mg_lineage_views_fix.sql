-- =============================================================================
-- OSA / ISA — PATCH MG LINEAGE VIEWS FIX
-- Correction : STRING_AGG ORDER BY non supporté dans window function PostgreSQL
-- Remplace v_lineage_refresh_order par une CTE avec GROUP BY
-- Le freeze P7K V3 et isa_view_lineage_registry sont déjà en place
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- v_lineage_refresh_order — corrigée
-- STRING_AGG avec ORDER BY dans GROUP BY (pas window function)
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
        MIN(l.refresh_order)                            AS refresh_order,
        l.source_schema                                 AS schema_name,
        l.source_object                                 AS object_name,
        MIN(l.source_object_type)                       AS object_type,
        MIN(l.package_code)                             AS package_code,
        COUNT(*)                                        AS nb_dependencies,
        STRING_AGG(
            l.target_schema || '.' || l.target_object,
            ', ' ORDER BY l.target_object
        )                                               AS depends_on
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
-- v_lineage_cascade_risk — recréée pour être sûr
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS mg.v_lineage_cascade_risk;

CREATE VIEW mg.v_lineage_cascade_risk AS
SELECT
    l.target_schema || '.' || l.target_object           AS at_risk_object,
    l.target_object_type,
    COUNT(*)                                            AS nb_dependents,
    STRING_AGG(
        l.source_schema || '.' || l.source_object,
        ', ' ORDER BY l.refresh_order, l.source_object
    )                                                   AS dependent_objects,
    MAX(l.refresh_order)                                AS max_refresh_order,
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
-- v_lineage_dependency_chain — recréée pour être sûr
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS mg.v_lineage_dependency_chain;

CREATE VIEW mg.v_lineage_dependency_chain AS
SELECT
    l.refresh_order,
    l.source_schema || '.' || l.source_object           AS source_object_full,
    l.source_object_type,
    l.dependency_type,
    l.cascade_risk,
    l.target_schema || '.' || l.target_object           AS target_object_full,
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
-- Validation
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_views     INTEGER;
    v_refresh   INTEGER;
    v_cascade   INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_views
        FROM information_schema.views
        WHERE table_schema = 'mg'
          AND table_name IN (
              'v_lineage_dependency_chain',
              'v_lineage_refresh_order',
              'v_lineage_cascade_risk');

    SELECT COUNT(*) INTO v_refresh
        FROM mg.v_lineage_refresh_order;

    SELECT COUNT(*) INTO v_cascade
        FROM mg.v_lineage_cascade_risk;

    RAISE NOTICE 'MG lineage views fix : views=%, refresh_rows=%, cascade_rows=%',
        v_views, v_refresh, v_cascade;

    IF v_views <> 3 THEN
        RAISE EXCEPTION 'ABORT : vues MG manquantes (attendu 3, obtenu %)', v_views;
    END IF;
    IF v_refresh = 0 THEN
        RAISE EXCEPTION 'ABORT : v_lineage_refresh_order vide';
    END IF;
END $$;

COMMIT;
