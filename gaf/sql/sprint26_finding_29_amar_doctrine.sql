-- ============================================================
-- GAF Finding #29 — AMAR_YEAR_ZERO_DISPLAY
-- Decision doctrinale : perimetre AMAR commence en 2021
-- Sprint 26 — 23 juin 2026
-- Conseil technique OSA
-- ============================================================
-- EXÉCUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint26_finding_29_amar_doctrine.sql
-- ============================================================

INSERT INTO ops.audit_findings (
    audit_id, module, finding_code, finding_hash, severity,
    publication_impact, iprs_weight, object_type, object_code,
    description, raw_finding, status
) VALUES (
    'a592c23b-423e-401f-aee4-a73fddce1129',
    'PORTAL-AMAR',
    'AMAR_YEAR_ZERO_DISPLAY',
    md5('PORTAL-AMAR|AMAR_YEAR_ZERO_DISPLAY|mg.v_public_p7i_amar_alerts'),
    'MEDIUM',
    'CONDITIONAL',
    0.00,
    'VIEW_AND_FRONTEND',
    'mg.v_public_p7i_amar_alerts + portal-v2',
    'GAF-PORTAL-AMAR-001 -- Perimetre doctrinal AMAR : 2021 (triggers formels). '
    || 'La vue mg.v_public_p7i_amar_alerts expose des donnees 2010-2024 '
    || 'dont les annees 2010-2020 pre-datent le perimetre doctrinal officiel. '
    || 'Le portail affiche une variation en 2020 pour AMAR et GENECO '
    || 'alors que 2020 est l''annee zero sans variation calculable. '
    || 'Decision Conseil technique : AMAR commence en 2021 (triggers formels). '
    || 'Actions : filtrer les vues mg sur year >= 2021, '
    || 'afficher -- en 2020 dans le portail, '
    || 'filtrer amar_risk_band sur year >= 2021 dans opendata.',
    '{"reference": "GAF-PORTAL-AMAR-001", "sprint": "Sprint 26",
      "doctrine_decision": {
        "amar_official_start": 2021,
        "rationale": "Triggers formels bases sur THR/WKN SWOT non disponible avant 2021",
        "decided_by": "Conseil technique OSA"
      },
      "actions_required": [
        "Filtrer mg.v_public_p7i_amar_alerts sur year >= 2021",
        "Filtrer mg.v_public_p7i_amar_geneco_alerts sur year >= 2021",
        "Portail : afficher -- pour amar_risk_band en 2020",
        "API opendata : retourner null pour amar_risk_band en year < 2021",
        "Mettre a jour page Methodologie : perimetre AMAR 2021-2024"
      ],
      "impact": {
        "open_data": "CONDITIONAL",
        "portal_display": "CONDITIONAL",
        "triggers_engine": "AUCUN"
      }
    }'::jsonb,
    'OPEN'
) ON CONFLICT DO NOTHING;
