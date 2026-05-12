-- ============================================================
-- OSA / ISA — P7F
-- View: ma.v_isa_public_consultation_topics
-- Purpose: public consultation topics from diagnostics.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_public_consultation_topics AS
WITH mapped AS (
    SELECT
        d.country_iso3,
        d.year,
        d.pillar_code,
        c.intervention_family_code,
        c.intervention_family_label,
        c.strategic_diagnostic_role,
        c.priority_score,
        c.diagnostic_evidence_status,
        CASE
            WHEN c.strategic_diagnostic_role = 'WEAKNESS_TO_FIX' THEN 'WEAKNESS_DIAGNOSTIC_REVIEW'
            WHEN c.strategic_diagnostic_role = 'THREAT_TO_MITIGATE' THEN 'RISK_EVIDENCE_REVIEW'
            WHEN c.strategic_diagnostic_role = 'STRENGTH_TO_SCALE' THEN 'STRENGTH_REPLICATION_FEEDBACK'
            WHEN c.strategic_diagnostic_role = 'OPPORTUNITY_TO_ACCELERATE' THEN 'OPPORTUNITY_EXPLORATION_FEEDBACK'
            ELSE 'GENERAL_OBSERVATORY_FEEDBACK'
        END AS consultation_topic_type,
        f.consultation_theme AS consultation_topic_label
    FROM ma.v_isa_strategic_diagnostic_engine d
    LEFT JOIN ma.v_isa_candidate_intervention_catalog c
      ON c.country_iso3 = d.country_iso3
     AND c.year = d.year
     AND c.pillar_code = d.pillar_code
    LEFT JOIN rf.isa_candidate_intervention_family f
      ON f.pillar_code = d.pillar_code
)
SELECT
    m.country_iso3,
    m.year,
    m.pillar_code,
    m.intervention_family_code,
    m.intervention_family_label,
    m.strategic_diagnostic_role,
    m.priority_score,
    m.diagnostic_evidence_status,
    m.consultation_topic_type,
    COALESCE(p.topic_label, 'Feedback général observatoire') AS consultation_type_label,
    COALESCE(m.consultation_topic_label, 'Consultation publique sur le diagnostic observé.') AS consultation_topic_label,
    CASE
        WHEN m.priority_score >= 0.75 THEN 'PUBLIC_CONSULTATION_HIGH_PRIORITY'
        WHEN m.priority_score >= 0.55 THEN 'PUBLIC_CONSULTATION_STANDARD_PRIORITY'
        ELSE 'PUBLIC_CONSULTATION_MONITORING'
    END AS consultation_priority,
    'P7F_PUBLIC_DIAGNOSTIC_CONSULTATION'::TEXT AS consultation_scope
FROM mapped m
LEFT JOIN rf.isa_public_consultation_policy p
  ON p.consultation_topic_type = m.consultation_topic_type;
