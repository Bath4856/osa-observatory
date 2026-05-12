-- ============================================================
-- OSA / ISA — P8G View: ma.v_isa_eparticipation_queue
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_eparticipation_queue AS
SELECT
    e.*,
    p.queue_priority,
    p.requires_moderation,
    p.allows_public_comment,
    p.allows_evidence_upload,
    p.policy_note,
    CASE
        WHEN e.eparticipation_priority = 'EPARTICIPATION_HIGH_PRIORITY'
            THEN 'QUEUE_HIGH_PRIORITY'
        WHEN e.eparticipation_priority = 'EPARTICIPATION_STANDARD_PRIORITY'
            THEN 'QUEUE_STANDARD_PRIORITY'
        ELSE 'QUEUE_MONITORING'
    END AS eparticipation_queue_status
FROM ma.v_isa_eparticipation_priorities e
LEFT JOIN rf.isa_eparticipation_policy p
    ON p.topic_type = e.eparticipation_topic_type;
