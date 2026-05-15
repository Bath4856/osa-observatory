-- =============================================================================
-- OSA / ISA — PATCH MG PG_MATVIEWS FIX
-- Crée une fonction helper mg.fn_check_matview()
-- Centralise la vérification des MV pour tous les scripts futurs
-- Évite le bug information_schema.tables qui ne liste pas les MV
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS mg;

-- -----------------------------------------------------------------------------
-- mg.fn_check_matview(schema, matview_name)
-- Retourne 'OK' si la MV existe, 'MISSING' sinon
-- À utiliser dans tous les pré-checks des scripts OSA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mg.fn_check_matview(
    p_schema    TEXT,
    p_matview   TEXT
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM pg_matviews
            WHERE schemaname  = p_schema
              AND matviewname = p_matview
        ) THEN 'OK'
        ELSE 'MISSING'
    END;
$$;

COMMENT ON FUNCTION mg.fn_check_matview IS
    'Vérifie l''existence d''une materialized view via pg_matviews.
     Ne pas utiliser information_schema.tables pour les MV — elle ne les liste pas.
     Usage : SELECT mg.fn_check_matview(''ma'', ''mv_isa_executive_master_board'')';

-- -----------------------------------------------------------------------------
-- mg.fn_check_view(schema, view_name)
-- Retourne 'OK' si la vue existe, 'MISSING' sinon
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mg.fn_check_view(
    p_schema    TEXT,
    p_view      TEXT
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.views
            WHERE table_schema = p_schema
              AND table_name   = p_view
        ) THEN 'OK'
        ELSE 'MISSING'
    END;
$$;

COMMENT ON FUNCTION mg.fn_check_view IS
    'Vérifie l''existence d''une vue via information_schema.views.
     Usage : SELECT mg.fn_check_view(''ma'', ''v_isa_executive_priority_portfolio'')';

-- -----------------------------------------------------------------------------
-- mg.fn_check_table(schema, table_name)
-- Retourne 'OK' si la table existe, 'MISSING' sinon
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mg.fn_check_table(
    p_schema    TEXT,
    p_table     TEXT
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = p_schema
              AND table_name   = p_table
              AND table_type   = 'BASE TABLE'
        ) THEN 'OK'
        ELSE 'MISSING'
    END;
$$;

COMMENT ON FUNCTION mg.fn_check_table IS
    'Vérifie l''existence d''une table via information_schema.tables.
     Usage : SELECT mg.fn_check_table(''rf'', ''isa_executive_cost_model'')';

-- -----------------------------------------------------------------------------
-- Validation
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_fn_matview TEXT;
    v_fn_view    TEXT;
    v_fn_table   TEXT;
BEGIN
    -- Test fn_check_matview sur une MV connue
    SELECT mg.fn_check_matview('ma', 'mv_isa_executive_master_board')
        INTO v_fn_matview;
    -- Test fn_check_view sur une vue connue
    SELECT mg.fn_check_view('mg', 'v_cost_model_review_due')
        INTO v_fn_view;
    -- Test fn_check_table sur une table connue
    SELECT mg.fn_check_table('rf', 'isa_executive_cost_model')
        INTO v_fn_table;

    RAISE NOTICE 'pg_matviews fix : fn_check_matview=%, fn_check_view=%, fn_check_table=%',
        v_fn_matview, v_fn_view, v_fn_table;

    IF v_fn_matview <> 'OK' THEN
        RAISE EXCEPTION 'ABORT : mv_isa_executive_master_board non détectée par fn_check_matview';
    END IF;
    IF v_fn_view <> 'OK' THEN
        RAISE EXCEPTION 'ABORT : v_cost_model_review_due non détectée par fn_check_view';
    END IF;
    IF v_fn_table <> 'OK' THEN
        RAISE EXCEPTION 'ABORT : isa_executive_cost_model non détectée par fn_check_table';
    END IF;
END $$;

COMMIT;
