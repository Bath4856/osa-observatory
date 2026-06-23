-- ============================================================
-- Sprint 25 -- GAF finding #20 update final
-- Ajout des resultats Sprint 25 dans raw_finding
-- 23 juin 2026
-- ============================================================

UPDATE ops.audit_findings
SET
    description = description || E'\n\n--- Sprint 25 : AMAR Trigger Engine livre en production (23 juin 2026) ---\n'
    || E'Architecture de court-circuit implementee conformement a la decision du Conseil technique (22 juin 2026). '
    || E'Le Strategic Risk Score reste inchange. '
    || E'Un AMAR Trigger Engine independant est desormais actif en production (GET /api/v2/amar/triggers). '
    || E'Backfill 2020-2024 charge : 18 triggers (EXCEPTIONAL=2, CRITICAL=3, ACTIVE=13, INCOMPLETE=0). '
    || E'Anomalie WKN : SDN 2024 PENV wkn_score corrige (NULL, wkn_missing=TRUE) -- finding #24 ouvert. '
    || E'Points ouverts pour Sprint 2 Trigger Engine : ponderation pilier-specifique, absence triggers 2023, weakness_score_raw dans ma.v_p7i_risk_source.',

    raw_finding = raw_finding || jsonb_build_object(
        'sprint25_delivery', jsonb_build_object(
            'delivered_at',         '2026-06-23',
            'status',               'PRODUCTION',
            'objects_created', jsonb_build_array(
                'pub.trigger_classify()',
                'pub.amar_triggers',
                'pub.v_amar_trigger_log',
                'GET /api/v2/amar/triggers',
                'GET /api/v2/amar/triggers/{iso3}'
            ),
            'backfill', jsonb_build_object(
                'period',           '2020-2024',
                'n_total',          2700,
                'n_triggers',       18,
                'EXCEPTIONAL',      2,
                'CRITICAL',         3,
                'ACTIVE',           13,
                'INCOMPLETE',       0,
                'trigger_rate_pct', 0.67
            ),
            'anomaly_resolved', jsonb_build_object(
                'finding_id',       24,
                'code',             'WKN_PENV_NULL_MASKED_SDN_2024',
                'correction',       'wkn_score=NULL, wkn_missing=TRUE pour SDN 2024 PENV',
                'classification_impact', 'Aucun -- TRIGGER_EXCEPTIONAL maintenu (Option B)'
            ),
            'open_points_sprint2', jsonb_build_array(
                'Ponderation pilier-specifique Trigger Engine',
                'Absence triggers 2023 -- pipeline ACLED SDN a verifier',
                'weakness_score_raw dans ma.v_p7i_risk_source (finding #24)'
            ),
            'related_findings', jsonb_build_array(
                jsonb_build_object('finding_id', 23, 'code', 'AMAR_TRIGGER_PREREQUISITES_VALIDATED'),
                jsonb_build_object('finding_id', 24, 'code', 'WKN_PENV_NULL_MASKED_SDN_2024')
            )
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, status, updated_at;
