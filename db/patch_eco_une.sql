-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : Ajout ECO_UNE (chômage) — pilier PECO
-- Contexte : ECO_UNE était mappé dans fetcher_imf.py mais absent
--            de rf.indicators → crash FK à l'insertion.
-- Action   : ajout en 16e indicateur PECO + rééquilibrage 1/16
-- Date     : 2026-03-28
-- ============================================================

BEGIN;

-- ============================================================
-- 1. rf.indicators — ajout ECO_UNE
--    Le trigger trg_protect_indicators bloque UPDATE/DELETE,
--    pas INSERT → on peut insérer normalement.
-- ============================================================

INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code,
     direction, description, display_order, is_active)
VALUES
    ('ECO_UNE',
     'Taux de chômage',
     'Unemployment rate',
     'PECO',
     'PERCENT',
     '-',
     'Taux de chômage modélisé (% population active) — source IMF WEO LUR',
     16,
     TRUE)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2. rf.indicator_meta_link — rééquilibrage PECO à 1/16
--    (UPDATE autorisé sur cette table — pas de trigger protect)
-- ============================================================

UPDATE rf.indicator_meta_link
SET    weight = ROUND(1.0 / 16, 8)
WHERE  meta_code = 'SOV_PECO';

-- Ajout du lien ECO_UNE
INSERT INTO rf.indicator_meta_link (meta_code, indicator_code, weight, is_active)
VALUES ('SOV_PECO', 'ECO_UNE', ROUND(1.0 / 16, 8), TRUE)
ON CONFLICT (meta_code, indicator_code) DO UPDATE
    SET weight = ROUND(1.0 / 16, 8),
        is_active = TRUE;

-- ============================================================
-- 3. ma.indicator_meta — métadonnées analytiques
-- ============================================================

INSERT INTO ma.indicator_meta
    (indicator_code, label, description, unit_code, polarity, pillar_code, is_active)
VALUES
    ('ECO_UNE',
     'Taux de chômage',
     'Taux de chômage modélisé (% population active) — source IMF WEO LUR',
     'PERCENT',
     'NEG',
     'PECO',
     TRUE)
ON CONFLICT (indicator_code) DO NOTHING;

-- ============================================================
-- 4. ma.indicator_meta_links — rééquilibrage PECO à 1/16
-- ============================================================

UPDATE ma.indicator_meta_links
SET    weight = ROUND(1.0 / 16, 8)
WHERE  meta_code = 'SOV_PECO';

-- Ajout du lien ECO_UNE
INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, is_inverse, ref_year, is_active)
VALUES
    ('SOV_PECO', 'ECO_UNE', ROUND(1.0 / 16, 8), FALSE, 2024, TRUE)
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight    = ROUND(1.0 / 16, 8),
        is_active = TRUE;

-- ============================================================
-- 5. mm.indicator_group_links — rattachement au groupe GPECO
-- ============================================================

INSERT INTO mm.indicator_group_links (group_code, indicator_code)
VALUES ('GPECO', 'ECO_UNE')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. Vérifications post-patch
-- ============================================================

DO $$
DECLARE
    v_count     INT;
    v_sum       NUMERIC;
    v_ind_exist BOOLEAN;
BEGIN
    -- ECO_UNE présent dans rf.indicators
    SELECT EXISTS (SELECT 1 FROM rf.indicators WHERE code = 'ECO_UNE')
    INTO v_ind_exist;
    IF NOT v_ind_exist THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : ECO_UNE absent de rf.indicators';
    END IF;

    -- Nombre d'indicateurs PECO actifs
    SELECT COUNT(*) INTO v_count
    FROM rf.indicators
    WHERE pillar_code = 'PECO' AND is_active = TRUE;
    IF v_count <> 15 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : PECO a % indicateurs actifs (attendu 15)', v_count;
    END IF;

    -- Somme des poids PECO ≈ 1.0
    SELECT SUM(weight) INTO v_sum
    FROM rf.indicator_meta_link
    WHERE meta_code = 'SOV_PECO' AND is_active = TRUE;
    IF ABS(v_sum - 1.0) > 0.07 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : somme poids PECO = % (attendu ≈ 1.0)', v_sum;
    END IF;

    RAISE NOTICE 'PATCH OK — ECO_UNE ajouté, PECO = % indicateurs, somme poids = %',
        v_count, v_sum;
END;
$$;

COMMIT;

-- ============================================================
-- Contrôle rapide post-déploiement
-- ============================================================
-- SELECT code, name_fr, direction, display_order
-- FROM   rf.indicators
-- WHERE  pillar_code = 'PECO'
-- ORDER  BY display_order;
--
-- SELECT indicator_code, weight
-- FROM   rf.indicator_meta_link
-- WHERE  meta_code = 'SOV_PECO'
-- ORDER  BY indicator_code;
--
-- SELECT SUM(weight) FROM rf.indicator_meta_link WHERE meta_code = 'SOV_PECO';
-- -- attendu : 1.00000000 (16 × 0.06250000)
