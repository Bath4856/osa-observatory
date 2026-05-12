-- ============================================================
-- OSA / ISA — P8B View: ma.v_isa_publication_governance
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_publication_governance AS
WITH governed AS (
    SELECT
        c.*,
        CASE
            WHEN c.certification_status = 'CERTIFIED' THEN 'PUBLISHED'
            WHEN c.certification_status = 'PROVISIONAL' THEN 'PUBLISHED'
            WHEN c.certification_status = 'REVIEW_REQUIRED' THEN 'EXPERT_REVIEW'
            ELSE 'DRAFT'
        END AS workflow_status
    FROM ma.v_isa_certification_engine c
)
SELECT
    g.*,
    w.workflow_order,
    w.is_terminal,
    w.is_public,
    w.requires_certification,
    w.workflow_note,
    CASE
        WHEN g.workflow_status = 'PUBLISHED' AND g.certification_status = 'CERTIFIED'
            THEN 'PUBLICATION_OFFICIAL_READY'
        WHEN g.workflow_status = 'PUBLISHED' AND g.certification_status = 'PROVISIONAL'
            THEN 'PUBLICATION_PROVISIONAL_READY'
        WHEN g.workflow_status = 'EXPERT_REVIEW'
            THEN 'PUBLICATION_REVIEW_REQUIRED'
        ELSE 'PUBLICATION_NOT_READY'
    END AS publication_governance_status
FROM governed g
LEFT JOIN rf.isa_publication_workflow_policy w
    ON w.workflow_status = g.workflow_status;
