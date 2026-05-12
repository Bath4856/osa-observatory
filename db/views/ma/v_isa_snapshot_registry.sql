-- ============================================================
-- OSA / ISA — P8C View: ma.v_isa_snapshot_registry
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_snapshot_registry AS
SELECT
    country_iso3,
    year,
    publication_status,
    certification_status,
    workflow_status,
    CASE
        WHEN certification_status = 'CERTIFIED' THEN 'OFFICIAL_ANNUAL'
        WHEN certification_status = 'PROVISIONAL' THEN 'PROVISIONAL'
        ELSE 'INTERNAL_REVIEW'
    END AS snapshot_type,
    CONCAT(
        'ISA_', year, '_', country_iso3, '_',
        CASE
            WHEN certification_status = 'CERTIFIED' THEN 'OFFICIAL'
            WHEN certification_status = 'PROVISIONAL' THEN 'PROVISIONAL'
            ELSE 'REVIEW'
        END
    ) AS snapshot_code,
    'ISA_P8_V1'::TEXT AS methodology_signature,
    MD5(CONCAT_WS('|',
        country_iso3,
        year,
        publication_status,
        certification_status,
        workflow_status,
        isa_observed_score,
        sovereignty_observed_score,
        vulnerability_observed_score,
        certification_audit_hash
    )) AS snapshot_hash,
    CASE
        WHEN certification_status = 'CERTIFIED' THEN TRUE
        ELSE FALSE
    END AS freeze_eligible,
    CASE
        WHEN certification_status = 'CERTIFIED' THEN 'FREEZE_READY'
        WHEN certification_status = 'PROVISIONAL' THEN 'PROVISIONAL_NOT_IMMUTABLE'
        ELSE 'NOT_FREEZE_READY'
    END AS snapshot_freeze_status
FROM ma.v_isa_publication_governance;
