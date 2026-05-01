-- ================================================================
-- VUE DE SYNTHESE DES INDICATEURS CALCULES
-- ma.v_computed_full
-- Expose les 20 indicateurs calcules avec leur contexte pilier
-- ================================================================

CREATE VIEW ma.v_computed_full AS
SELECT
    ci.code,
    ci.pillar_code,
    p.name_fr                   AS pilier_nom,
    pt.pillar_type,
    pt.niveau_certification,
    ci.indicator_type,
    ci.name_fr                  AS indicateur_nom,
    ci.formula,
    ci.is_active,
    ci.created_at
FROM ma.computed_indicators ci
JOIN rf.pillars p       ON p.code          = ci.pillar_code
JOIN ma.pillar_type pt  ON pt.pillar_code  = ci.pillar_code
ORDER BY ci.pillar_code, ci.indicator_type;

COMMENT ON VIEW ma.v_computed_full IS
'Vue de synthese des 20 indicateurs calcules OSA (10 WEAKNESS + 10 THREAT) avec contexte pilier et typologie. Source de reference pour le moteur de calcul ISA.';

-- ── VERIFICATION FINALE ───────────────────────────────────────────
SELECT
    pillar_type,
    indicator_type,
    COUNT(*) AS nb,
    STRING_AGG(code, ', ' ORDER BY code) AS codes
FROM ma.v_computed_full
GROUP BY pillar_type, indicator_type
ORDER BY pillar_type, indicator_type;
