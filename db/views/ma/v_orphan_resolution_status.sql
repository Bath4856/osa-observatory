-- ============================================================
-- VIEW : ma.v_orphan_resolution_status
-- Objectif : suivi zéro orphelin ISA
-- ============================================================

CREATE OR REPLACE VIEW ma.v_orphan_resolution_status AS
SELECT
    m.pillar_code,
    m.indicator_code,
    i.name_fr,
    COALESCE(n.nature_code, 'UNCLASSIFIED') AS nature_code,
    m.mapping_exists,
    m.mapping_active,
    m.coverage_score,
    m.provider_score,
    m.data_confidence,
    m.registry_score,
    m.mapping_quality_score,
    m.quality_class,
    m.isa_status,
    m.orphan_flag,
    CASE
        WHEN m.orphan_flag = 'ORPHELIN' THEN 'A_TRAITER'
        WHEN m.mapping_quality_score < 0.50 THEN 'FAIBLE_QUALITE'
        ELSE 'RESOLU'
    END AS resolution_status
FROM ma.v_mapping_quality_score m
JOIN rf.indicators i ON i.code = m.indicator_code
LEFT JOIN rf.indicator_nature n ON n.indicator_code = m.indicator_code;
