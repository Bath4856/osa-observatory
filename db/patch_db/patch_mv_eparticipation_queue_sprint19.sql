
BEGIN;

-- ============================================================
-- OSA Observatory -- Sprint 19 post-runbook
-- Materialisation ma.v_isa_eparticipation_queue
-- Resolution timeout 504/116s sur /api/v1/consultation
-- ============================================================

-- Etape 1 : DROP des vues dependantes (ordre inverse)
DROP VIEW IF EXISTS pub.v_isa_public_consultation_topics;
DROP VIEW IF EXISTS ma.v_isa_eparticipation_priorities;

-- Etape 2 : Creer la MV depuis la definition originale
CREATE MATERIALIZED VIEW ma.mv_isa_eparticipation_queue AS
WITH ranked AS (
    SELECT r_1.country_iso3, r_1.year, r_1.pillar_code,
           r_1.trajectory_class, r_1.intervention_priority_class,
           r_1.intervention_priority_score, r_1.consultation_theme,
           r_1.intervention_family_label, r_1.intervention_family_code,
           ca.region_code, rg.name_fr AS region_label,
           CASE
               WHEN r_1.trajectory_class = 'CRITICAL' THEN 'RISK_EVIDENCE_REVIEW'
               WHEN r_1.trajectory_class = 'DECLINING' THEN 'WEAKNESS_DIAGNOSTIC_REVIEW'
               WHEN r_1.trajectory_class = ANY (ARRAY['ACCELERATING','PROGRESSING']) THEN 'STRENGTH_REPLICATION_FEEDBACK'
               WHEN r_1.trajectory_class = 'STABLE' AND r_1.intervention_priority_class = 'PRIORITY_HIGH' THEN 'OPPORTUNITY_EXPLORATION_FEEDBACK'
               ELSE 'GENERAL_OBSERVATORY_FEEDBACK'
           END AS consultation_type,
           CASE r_1.intervention_priority_class
               WHEN 'PRIORITY_CRITICAL' THEN 1
               WHEN 'PRIORITY_HIGH' THEN 2
               WHEN 'PRIORITY_STANDARD' THEN 3
               ELSE 4
           END AS queue_priority,
           count(cr.response_id) AS nb_responses,
           count(cr.response_id) FILTER (WHERE cr.moderation_status = 'APPROVED' AND cr.is_public = true) AS nb_approved_responses,
           CASE
               WHEN count(cr.response_id) = 0 THEN 'OPEN_NO_RESPONSE'
               WHEN count(cr.response_id) FILTER (WHERE cr.moderation_status = 'APPROVED') > 0 THEN 'ACTIVE_WITH_RESPONSES'
               ELSE 'OPEN_PENDING_MODERATION'
           END AS consultation_status
    FROM ma.v_p7j_recommendation_engine r_1
    LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = r_1.country_iso3
    LEFT JOIN rf.regions rg ON rg.code::text = ca.region_code::text
    LEFT JOIN mg.consultation_responses cr
        ON cr.country_iso3 = r_1.country_iso3
       AND cr.year = r_1.year
       AND cr.pillar_code::text = r_1.pillar_code::text
    WHERE r_1.year = (SELECT max(year) FROM ma.v_p7j_recommendation_engine)
    GROUP BY r_1.country_iso3, r_1.year, r_1.pillar_code,
             r_1.trajectory_class, r_1.intervention_priority_class,
             r_1.intervention_priority_score, r_1.consultation_theme,
             r_1.intervention_family_label, r_1.intervention_family_code,
             ca.region_code, rg.name_fr
)
SELECT r.country_iso3, r.year, r.pillar_code, r.trajectory_class,
       r.intervention_priority_class, r.intervention_priority_score,
       r.consultation_theme, r.intervention_family_label, r.intervention_family_code,
       r.region_code, r.region_label, r.consultation_type, r.queue_priority,
       r.nb_responses, r.nb_approved_responses, r.consultation_status,
       p.requires_moderation, p.allows_public_comment,
       p.allows_evidence_upload, p.policy_note
FROM ranked r
LEFT JOIN rf.isa_eparticipation_policy p ON p.topic_type::text = r.consultation_type
ORDER BY r.queue_priority, r.intervention_priority_score DESC;

-- Index unique sur (country_iso3, pillar_code)
CREATE UNIQUE INDEX idx_mv_eparticipation_queue_country_pillar
    ON ma.mv_isa_eparticipation_queue (country_iso3, pillar_code);

-- Etape 3 : Recreer ma.v_isa_eparticipation_priorities depuis la MV
CREATE VIEW ma.v_isa_eparticipation_priorities AS
SELECT country_iso3, year, region_code, region_label,
       count(*) AS total_consultations,
       count(*) FILTER (WHERE consultation_type = 'RISK_EVIDENCE_REVIEW') AS nb_risk_reviews,
       count(*) FILTER (WHERE consultation_type = 'WEAKNESS_DIAGNOSTIC_REVIEW') AS nb_weakness_reviews,
       count(*) FILTER (WHERE consultation_type = 'OPPORTUNITY_EXPLORATION_FEEDBACK') AS nb_opportunity_feedbacks,
       count(*) FILTER (WHERE consultation_type = 'STRENGTH_REPLICATION_FEEDBACK') AS nb_strength_feedbacks,
       count(*) FILTER (WHERE queue_priority = 1) AS nb_priority_critical,
       count(*) FILTER (WHERE queue_priority = 2) AS nb_priority_high,
       sum(nb_responses) AS total_responses,
       sum(nb_approved_responses) AS total_approved_responses,
       round(CASE WHEN count(*) > 0 THEN sum(nb_approved_responses) / count(*)::numeric ELSE 0 END, 4) AS avg_engagement_score,
       CASE
           WHEN sum(nb_approved_responses) > 5 THEN 'HIGH_ENGAGEMENT'
           WHEN sum(nb_approved_responses) > 0 THEN 'ACTIVE'
           ELSE 'NO_ENGAGEMENT'
       END AS engagement_status
FROM ma.mv_isa_eparticipation_queue q
GROUP BY country_iso3, year, region_code, region_label
ORDER BY (count(*) FILTER (WHERE queue_priority = 1)) DESC, (count(*)) DESC;

-- Etape 4 : Recreer pub.v_isa_public_consultation_topics depuis la MV
CREATE VIEW pub.v_isa_public_consultation_topics AS
SELECT q.country_iso3, q.year, q.pillar_code, q.region_code, q.region_label,
       q.trajectory_class, q.consultation_type,
       cp.topic_label AS consultation_label,
       q.consultation_theme, q.intervention_family_label,
       q.queue_priority, q.consultation_status, q.nb_approved_responses,
       q.allows_public_comment, q.allows_evidence_upload,
       'Share your knowledge at open.osa-observatory.org/consult'::text AS participation_call,
       'OSA Observatory -- CC-BY-NC-4.0'::text AS source
FROM ma.mv_isa_eparticipation_queue q
LEFT JOIN rf.isa_public_consultation_policy cp
    ON cp.consultation_topic_type::text = q.consultation_type
WHERE cp.public_open = true AND q.queue_priority <= 3
ORDER BY q.queue_priority, q.country_iso3, q.pillar_code;

COMMENT ON MATERIALIZED VIEW ma.mv_isa_eparticipation_queue IS
    'Vue materialisee -- file e-participation. Remplace v_isa_eparticipation_queue. Refresh apres integration donnees. Sprint 19 post-runbook -- resolution 504 (116s -> <5ms).';

COMMIT;
