-- ============================================================
-- OSA Observatory -- Patch pipeline L3->L7
-- Date : Avril 2026
-- Auteur : Session automatique
-- ============================================================
-- Corrections :
-- 1. run_pipeline_historical : cast smallint + rf.pillars + is_active
-- 2. compute_pillar_score : poids egaux dynamiques (AVG) + coverage_pct reel
-- 3. indicator_meta_links : duplication 2010-2023 depuis 2024
-- ============================================================

-- 1. Duplication des liens de poids pour 2010-2023
INSERT INTO ma.indicator_meta_links (meta_code, indicator_code, weight, is_inverse, ref_year, is_active)
SELECT meta_code, indicator_code, weight, is_inverse, y, is_active
FROM ma.indicator_meta_links
CROSS JOIN generate_series(2010, 2023) AS y
WHERE ref_year = 2024
ON CONFLICT DO NOTHING;
