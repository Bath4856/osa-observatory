-- ================================================================
-- MISE A JOUR DE ma.v_indicators_active
-- Integration de la typologie pilier
-- ================================================================

DROP VIEW IF EXISTS ma.v_indicators_active;

CREATE VIEW ma.v_indicators_active AS
SELECT
    i.*,
    pt.pillar_type,
    pt.seuil_exclusion,
    pt.niveau_certification,
    pt.imputation_rule
FROM rf.indicators i
LEFT JOIN ma.pillar_type pt ON pt.pillar_code = i.pillar_code
WHERE i.is_active = true
  AND NOT EXISTS (
      SELECT 1 FROM ma.indicator_exclusions e
      WHERE e.indicator_code = i.code
  );

COMMENT ON VIEW ma.v_indicators_active IS
'Referentiel net des indicateurs actifs -- sans doublons, avec typologie pilier. Source unique pour tous les calculs ISA, WEAKNESS et THREAT.';

-- Verification
SELECT
    pillar_code,
    pillar_type,
    niveau_certification,
    imputation_rule,
    COUNT(*) AS nb_indicateurs
FROM ma.v_indicators_active
GROUP BY pillar_code, pillar_type, niveau_certification, imputation_rule
ORDER BY pillar_type, pillar_code;
