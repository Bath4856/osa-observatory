-- OSA Observatory -- D2.4 Tableau de bord pilote
-- Vue mg.v_pilot_dashboard v2 -- Sprint 20 -- 4 juin 2026
-- Correction : temps_moyen et p95 hors RATE_LIMIT_EXCEEDED
DROP VIEW IF EXISTS mg.v_pilot_dashboard;
CREATE VIEW mg.v_pilot_dashboard AS
SELECT
    (SELECT COUNT(*) FROM rf.affiliations WHERE status='ACTIVE') AS utilisateurs_actifs,
    (SELECT COUNT(*) FROM rf.affiliations WHERE status='ACTIVE' AND access_level='STANDARD') AS utilisateurs_standard,
    (SELECT COUNT(*) FROM rf.affiliations WHERE status='ACTIVE' AND access_level='PREMIUM') AS utilisateurs_premium,
    (SELECT COUNT(*) FROM mg.api_usage_registry) AS consultations_total,
    (SELECT COUNT(*) FROM mg.api_usage_registry WHERE request_timestamp >= now()-interval '7 days') AS consultations_7j,
    (SELECT COUNT(*) FROM mg.api_usage_registry WHERE request_timestamp >= now()-interval '24 hours') AS consultations_24h,
    (SELECT ROUND(AVG(response_time_ms),1) FROM mg.api_usage_registry
     WHERE request_timestamp >= now()-interval '7 days'
       AND endpoint_code != 'RATE_LIMIT_EXCEEDED' AND response_time_ms > 0) AS temps_moyen_reponse_ms,
    (SELECT ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)::numeric,1)
     FROM mg.api_usage_registry
     WHERE request_timestamp >= now()-interval '7 days'
       AND endpoint_code != 'RATE_LIMIT_EXCEEDED' AND response_time_ms > 0) AS p95_reponse_ms,
    (SELECT COUNT(*) FROM mg.pilot_tickets) AS tickets_total,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE ticket_type='CONTESTATION') AS contestations,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE ticket_type='DEMANDE_ACCES') AS demandes_acces,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE ticket_type='DEMANDE_CORRECTION') AS demandes_correction,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE ticket_type='SUGGESTION') AS suggestions,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE ticket_type='QUESTION') AS questions,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE pol_level IS NOT NULL) AS amendements_total,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE pol_level='N1') AS amendements_n1,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE pol_level='N2') AS amendements_n2,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE pol_level IN ('N3','N4')) AS amendements_n3_n4,
    (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE status='RESOLU')/NULLIF(COUNT(*),0),1)
     FROM mg.pilot_tickets) AS taux_resolution,
    (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at-created_at))/3600),1)
     FROM mg.pilot_tickets WHERE status='RESOLU') AS temps_moyen_resolution_h,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE priority='URGENT' AND status='OUVERT') AS urgents_non_traites,
    (SELECT COUNT(*) FROM mg.pilot_tickets WHERE status='ESCALADE') AS escalades_actives,
    now() AS generated_at;
COMMENT ON VIEW mg.v_pilot_dashboard IS
    'Vue tableau de bord pilote OSA -- D2.4. Sprint 20 -- temps_moyen et p95 hors RATE_LIMIT_EXCEEDED.';
