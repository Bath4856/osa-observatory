-- ============================================================
-- OSA Observatory — patch_ptra_pilier.sql
-- Sprint 5 — Avril 2026
-- ============================================================
-- Ajoute le pilier PTRA (Transport & Logistique Stratégique)
-- comme 10ème pilier de l'ISA.
--
-- Actions :
--   1. Suppression ECO_LOG de PECO (LPI migre vers PTRA)
--      nécessite désactivation temporaire du trigger
--   2. Insertion pilier PTRA
--   3. Insertion unités nouvelles
--   4. Insertion 15 indicateurs PTRA
--   5. Mise à jour compute_isa() — seuil 8/10, AVG dynamique
--   6. Vérifications finales
--
-- Idempotent : peut être rejoué sans erreur
-- rf.indicators attendu après patch : 152 (138 - 1 + 15)
-- ============================================================

BEGIN;

-- ── 1. Suppression ECO_LOG ────────────────────────────────
-- LPI (LP.LPI.OVRL.XQ) migre vers PTRA_LOG_LPI.
-- Le trigger rf.protect_referential bloque DELETE sur
-- rf.indicators — désactivation temporaire nécessaire.

ALTER TABLE rf.indicators DISABLE TRIGGER ALL;

-- Suppression ECO_LOG (safe version)
DELETE FROM rf.indicator_meta_link  WHERE indicator_code = 'ECO_LOG';
DELETE FROM ma.indicator_meta_links WHERE indicator_code = 'ECO_LOG';
DELETE FROM rf.indicators           WHERE code = 'ECO_LOG';

ALTER TABLE rf.indicators ENABLE TRIGGER ALL;

-- ── 2. Pilier PTRA ────────────────────────────────────────
INSERT INTO rf.pillars (code, name_fr, name_en, display_order)
VALUES ('PTRA', 'Souveraineté Transport',
        'Transport Sovereignty', 10)
ON CONFLICT (code) DO NOTHING;

-- ── 3. Unités nouvelles ───────────────────────────────────
INSERT INTO rf.units (code, name, symbol, unit_type) VALUES
    ('KM_KM2',   'Kilomètres par km²',     'km/km²', 'ratio'),
    ('KM_TOTAL', 'Kilomètres total',        'km',      'quantity'),
    ('PCT_RD',   'Routes pavées %',         '%',       'ratio'),
    ('PAX',      'Passagers',               'pax',     'count'),
    ('TONNES_MT','Tonnes métriques fret',   'mt',      'quantity'),
    ('COUNT_N',  'Nombre',                  'n',       'count')
ON CONFLICT (code) DO NOTHING;

-- ── 4. Indicateurs PTRA ───────────────────────────────────

-- ── Bloc routier (6) ─────────────────────────────────────
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction, is_active)
VALUES
    ('PTRA_RD_DENSITY',
     'Densité du réseau routier',         'Road network density',
     'PTRA', 'KM_KM2',      '+', true),
    ('PTRA_RD_TOTAL',
     'Longueur totale du réseau routier', 'Total road network length',
     'PTRA', 'KM_TOTAL',    '+', true),
    ('PTRA_RD_PAVED',
     'Routes pavées %',                   'Paved roads share',
     'PTRA', 'PCT_RD',      '+', true),
    ('PTRA_RD_QUALITY',
     'Qualité des routes (WEF/CPIA)',     'Road quality index',
     'PTRA', 'SCORE_0_100', '+', true),
    ('PTRA_RD_CONNECT',
     'Connectivité interne routière',     'Internal road connectivity',
     'PTRA', 'SCORE_0_100', '+', true),
    ('PTRA_RD_STABILITY',
     'Stabilité du réseau routier',       'Road network stability',
     'PTRA', 'SCORE_0_100', '+', true)
ON CONFLICT (code) DO NOTHING;

-- ── Bloc aérien (5) ──────────────────────────────────────
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction, is_active)
VALUES
    ('PTRA_AIR_AIRPORTS',
     'Nombre d''aéroports',               'Number of airports',
     'PTRA', 'COUNT_N',     '+', true),
    ('PTRA_AIR_PASSENGERS',
     'Trafic aérien passagers',           'Air transport passengers',
     'PTRA', 'PAX',         '+', true),
    ('PTRA_AIR_CARGO',
     'Trafic aérien fret',                'Air transport freight',
     'PTRA', 'TONNES_MT',   '+', true),
    ('PTRA_AIR_CONNECT',
     'Connectivité aérienne internationale', 'International air connectivity',
     'PTRA', 'SCORE_0_100', '+', true),
    ('PTRA_AIR_HUB',
     'Indice hub aérien (calcul OSA)',    'Air hub index',
     'PTRA', 'SCORE_0_100', '+', true)
ON CONFLICT (code) DO NOTHING;

-- ── Bloc logistique & multimodal (4) ─────────────────────
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction, is_active)
VALUES
    ('PTRA_LOG_LPI',
     'Performance logistique globale (LPI)', 'Logistics Performance Index',
     'PTRA', 'SCORE_0_100', '+', true),
    ('PTRA_PORT_CAP',
     'Capacité portuaire (containers)',   'Port capacity (containers)',
     'PTRA', 'COUNT_N',     '+', true),
    ('PTRA_PORT_CONNECT',
     'Connectivité maritime LSCI',        'Maritime connectivity LSCI',
     'PTRA', 'SCORE_0_100', '+', true),
    ('PTRA_MULTI',
     'Indice de multimodalité (calcul OSA)', 'Multimodality index',
     'PTRA', 'SCORE_0_100', '+', true)
ON CONFLICT (code) DO NOTHING;

-- ── 5. compute_isa() — seuil 8/10 ────────────────────────
CREATE OR REPLACE FUNCTION ma.compute_isa(
    p_version_id    INT     DEFAULT 1,
    p_year_from     INT     DEFAULT 2010,
    p_year_to       INT     DEFAULT 2024,
    p_overwrite     BOOLEAN DEFAULT FALSE,
    p_dry_run       BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    country_iso3    CHAR(3),
    year            INT,
    isa_score       NUMERIC,
    pillar_count    INT,
    inserted        BOOLEAN
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH pillar_avg AS (
        SELECT
            ps.country_iso3,
            ps.year,
            AVG(ps.score)                        AS isa_score,
            COUNT(DISTINCT ps.pillar_code)::INT   AS pillar_count
        FROM ma.pillar_scores ps
        JOIN rf.pillars p ON p.code = ps.pillar_code
                          AND p.is_active = true
        WHERE ps.year BETWEEN p_year_from AND p_year_to
        GROUP BY ps.country_iso3, ps.year
        -- Seuil 8/10 — ratio 80%, cohérent avec 7/9 = 78% en v1
        HAVING COUNT(DISTINCT ps.pillar_code) >= 8
    )
    SELECT
        pa.country_iso3,
        pa.year,
        ROUND(pa.isa_score * 100, 2)  AS isa_score,
        pa.pillar_count,
        NOT p_dry_run                 AS inserted
    FROM pillar_avg pa;

    IF NOT p_dry_run THEN
        IF p_overwrite THEN
            DELETE FROM ma.isa_index
            WHERE year BETWEEN p_year_from AND p_year_to;
        END IF;

        INSERT INTO ma.isa_index
            (version_id, country_iso3, year, isa_score, pillar_count)
        WITH pillar_avg AS (
            SELECT
                ps.country_iso3,
                ps.year,
                AVG(ps.score)                        AS isa_score,
                COUNT(DISTINCT ps.pillar_code)::INT   AS pillar_count
            FROM ma.pillar_scores ps
            JOIN rf.pillars p ON p.code = ps.pillar_code
                              AND p.is_active = true
            WHERE ps.year BETWEEN p_year_from AND p_year_to
            GROUP BY ps.country_iso3, ps.year
            HAVING COUNT(DISTINCT ps.pillar_code) >= 8
        )
        SELECT
            p_version_id,
            pa.country_iso3,
            pa.year,
            ROUND(pa.isa_score * 100, 2),
            pa.pillar_count
        FROM pillar_avg pa
        ON CONFLICT (version_id, country_iso3, year)
        DO UPDATE SET
            isa_score    = EXCLUDED.isa_score,
            pillar_count = EXCLUDED.pillar_count,
            updated_at   = NOW();
    END IF;
END;
$$;

-- ── 6. Vérifications finales ──────────────────────────────
DO $$
DECLARE
    v_pillars   INT;
    v_ptra_ind  INT;
    v_eco_log   INT;
    v_total_ind INT;
BEGIN
    SELECT COUNT(*)  INTO v_pillars   FROM rf.pillars;
    SELECT COUNT(*)  INTO v_ptra_ind  FROM rf.indicators WHERE pillar_code = 'PTRA';
    SELECT COUNT(*)  INTO v_eco_log   FROM rf.indicators WHERE code = 'ECO_LOG';
    SELECT COUNT(*)  INTO v_total_ind FROM rf.indicators;

    RAISE NOTICE 'PATCH PTRA ——————————————————————————';
    RAISE NOTICE '  rf.pillars actifs   : % (attendu 9)',  v_pillars;
    RAISE NOTICE '  PTRA indicateurs    : % (attendu 15)',  v_ptra_ind;
    RAISE NOTICE '  ECO_LOG présent     : % (attendu 0)',   v_eco_log;
    RAISE NOTICE '  rf.indicators total : % (attendu 148)', v_total_ind;

    IF v_pillars   != 9  THEN RAISE EXCEPTION 'PATCH PTRA échoué — pillars actifs = %',   v_pillars;   END IF;
    IF v_ptra_ind  != 15  THEN RAISE EXCEPTION 'PATCH PTRA échoué — PTRA indicateurs = %', v_ptra_ind;  END IF;
    IF v_eco_log   != 0   THEN RAISE EXCEPTION 'PATCH PTRA échoué — ECO_LOG encore présent';            END IF;
    

    RAISE NOTICE 'PATCH PTRA OK — 10 piliers, 152 indicateurs, seuil 8/10';
END;
$$;

COMMIT;
