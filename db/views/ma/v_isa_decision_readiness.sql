CREATE OR REPLACE VIEW ma.v_isa_decision_readiness AS
SELECT pillar_code, decision_priority_class, decision_timing_code,
       COUNT(*)::INTEGER nb_decision_rows,
       COUNT(DISTINCT country_iso3)::INTEGER nb_countries,
       COUNT(DISTINCT year)::INTEGER nb_years,
       ROUND(AVG(decision_priority_score),3) avg_decision_priority_score,
       ROUND(AVG(decision_confidence_score),3) avg_decision_confidence_score,
       SUM(CASE WHEN decision_support_status='DECISION_BOARD_READY' THEN 1 ELSE 0 END)::INTEGER nb_board_ready,
       SUM(CASE WHEN decision_support_status='DECISION_LOW_CONFIDENCE_REVIEW' THEN 1 ELSE 0 END)::INTEGER nb_low_confidence,
       SUM(CASE WHEN decision_support_status='DECISION_WITH_SCENARIO_CAUTION' THEN 1 ELSE 0 END)::INTEGER nb_scenario_caution,
       CASE WHEN decision_priority_class='DECISION_CRITICAL' THEN 'P7J_DECISION_CRITICAL_READY'
            WHEN SUM(CASE WHEN decision_support_status='DECISION_LOW_CONFIDENCE_REVIEW' THEN 1 ELSE 0 END) > COUNT(*)*0.50 THEN 'P7J_DECISION_REVIEW_REQUIRED'
            WHEN decision_priority_class='DECISION_HIGH' THEN 'P7J_DECISION_HIGH_READY'
            WHEN decision_priority_class='DECISION_STANDARD' THEN 'P7J_DECISION_STANDARD_READY'
            ELSE 'P7J_DECISION_MONITORING' END AS p7j_decision_readiness_status
FROM ma.v_isa_decision_priority_engine
GROUP BY pillar_code, decision_priority_class, decision_timing_code;
