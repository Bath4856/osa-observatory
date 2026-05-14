CREATE OR REPLACE VIEW ma.v_isa_decision_priority_engine AS
WITH scenario AS (
 SELECT country_iso3::TEXT AS country_iso3, year::INTEGER AS year, pillar_code::TEXT AS pillar_code,
        MAX(CASE WHEN scenario_code='CENTRAL' THEN simulated_isa_delta END)::NUMERIC AS central_isa_delta,
        MAX(CASE WHEN scenario_code='AMBITIOUS' THEN simulated_isa_delta END)::NUMERIC AS ambitious_isa_delta,
        MAX(CASE WHEN scenario_code='STRESS' THEN simulated_isa_delta END)::NUMERIC AS stress_isa_delta,
        MAX(CASE WHEN scenario_code='CENTRAL' THEN simulation_decision END)::TEXT AS central_simulation_decision,
        MAX(CASE WHEN scenario_code='STRESS' THEN simulation_decision END)::TEXT AS stress_simulation_decision
 FROM ma.v_isa_scenario_simulation_engine
 WHERE scenario_code IN ('CENTRAL','AMBITIOUS','STRESS')
 GROUP BY country_iso3, year, pillar_code
), src AS (
 SELECT a.country_iso3::TEXT AS country_iso3, a.year::INTEGER AS year, a.pillar_code::TEXT AS pillar_code,
        a.intervention_family_code::TEXT AS intervention_family_code,
        a.intervention_family_label::TEXT AS intervention_family_label,
        a.strategic_objective::TEXT AS strategic_objective,
        a.recommended_action::TEXT AS recommended_action,
        a.candidate_intervention_status::TEXT AS candidate_intervention_status,
        a.sovereign_alert_level::TEXT AS sovereign_alert_level,
        a.early_warning_class::TEXT AS early_warning_class,
        COALESCE(a.early_warning_score,0)::NUMERIC AS early_warning_score,
        COALESCE(a.early_warning_confidence,0)::NUMERIC AS early_warning_confidence,
        COALESCE(a.intervention_alert_priority_score,0)::NUMERIC AS intervention_alert_priority_score,
        a.intervention_priority_class::TEXT AS intervention_priority_class,
        a.intervention_priority_label::TEXT AS intervention_priority_label,
        a.priority_intervention_action::TEXT AS priority_intervention_action,
        a.priority_intervention_alert_status::TEXT AS priority_intervention_alert_status,
        COALESCE(s.central_isa_delta,0)::NUMERIC AS central_isa_delta,
        COALESCE(s.ambitious_isa_delta,0)::NUMERIC AS ambitious_isa_delta,
        COALESCE(s.stress_isa_delta,0)::NUMERIC AS stress_isa_delta,
        COALESCE(s.central_simulation_decision,'UNKNOWN')::TEXT AS central_simulation_decision,
        COALESCE(s.stress_simulation_decision,'UNKNOWN')::TEXT AS stress_simulation_decision
 FROM ma.v_isa_priority_intervention_alerts a
 LEFT JOIN scenario s ON s.country_iso3=a.country_iso3::TEXT AND s.year=a.year::INTEGER AND s.pillar_code=a.pillar_code::TEXT
), scored AS (
 SELECT *,
        LEAST(1.0,GREATEST(0.0,
          0.38*early_warning_score + 0.32*intervention_alert_priority_score
          + 0.20*LEAST(1.0,GREATEST(0.0,ABS(ambitious_isa_delta)*5.0))
          + 0.10*LEAST(1.0,GREATEST(0.0,ABS(stress_isa_delta)*5.0))
        ))::NUMERIC raw_decision_priority_score,
        LEAST(1.0,GREATEST(0.0,
          0.55*early_warning_confidence
          + 0.25*CASE WHEN central_simulation_decision IN ('SIMULATION_USABLE_FOR_POLICY_DISCUSSION','SIMULATION_WITH_VOLATILITY_WARNING','BASELINE_REFERENCE','STRESS_TEST_ONLY') THEN 1.0 WHEN central_simulation_decision='SIMULATION_INDICATIVE_REVIEW_REQUIRED' THEN 0.60 ELSE 0.40 END
          + 0.20*CASE WHEN stress_simulation_decision='STRESS_TEST_ONLY' THEN 1.0 ELSE 0.70 END
        ))::NUMERIC decision_confidence_score
 FROM src
), raw_class AS (
 SELECT *, CASE WHEN raw_decision_priority_score>=0.750 THEN 'DECISION_CRITICAL' WHEN raw_decision_priority_score>=0.550 THEN 'DECISION_HIGH' WHEN raw_decision_priority_score>=0.350 THEN 'DECISION_STANDARD' ELSE 'DECISION_MONITOR' END::VARCHAR(30) raw_decision_priority_class
 FROM scored
), capped AS (
 SELECT r.*, c.max_decision_rank,
        CASE raw_decision_priority_class WHEN 'DECISION_CRITICAL' THEN 4 WHEN 'DECISION_HIGH' THEN 3 WHEN 'DECISION_STANDARD' THEN 2 ELSE 1 END raw_decision_rank
 FROM raw_class r LEFT JOIN rf.isa_decision_alert_cap_policy c ON c.sovereign_alert_level=r.sovereign_alert_level
), final_class AS (
 SELECT *, CASE
   WHEN COALESCE(max_decision_rank,4) >= raw_decision_rank THEN raw_decision_priority_class
   WHEN COALESCE(max_decision_rank,4)=3 THEN 'DECISION_HIGH'
   WHEN COALESCE(max_decision_rank,4)=2 THEN 'DECISION_STANDARD'
   ELSE 'DECISION_MONITOR' END::VARCHAR(30) decision_priority_class
 FROM capped
), pol AS (
 SELECT f.*, p.decision_rank, p.decision_label, p.decision_action, p.governance_track, p.public_decision_scope
 FROM final_class f JOIN rf.isa_decision_priority_policy p ON p.decision_priority_class=f.decision_priority_class
), timed AS (
 SELECT p.*, t.decision_timing_code AS decision_timing_code, t.timing_label AS decision_timing_label, t.max_months AS decision_max_months
 FROM pol p JOIN rf.isa_decision_timing_policy t ON t.timing_rank = p.decision_rank
)
SELECT country_iso3, year, pillar_code, intervention_family_code, intervention_family_label, strategic_objective, recommended_action,
       candidate_intervention_status, sovereign_alert_level, early_warning_class,
       ROUND(early_warning_score,3) early_warning_score, ROUND(early_warning_confidence,3) early_warning_confidence,
       ROUND(intervention_alert_priority_score,3) intervention_alert_priority_score,
       intervention_priority_class, intervention_priority_label, priority_intervention_action, priority_intervention_alert_status,
       ROUND(central_isa_delta,3) central_isa_delta, ROUND(ambitious_isa_delta,3) ambitious_isa_delta, ROUND(stress_isa_delta,3) stress_isa_delta,
       central_simulation_decision, stress_simulation_decision,
       ROUND(raw_decision_priority_score,3) decision_priority_score, ROUND(decision_confidence_score,3) decision_confidence_score,
       decision_priority_class, decision_rank, decision_label, decision_action, governance_track, public_decision_scope,
       decision_timing_code, decision_timing_label, decision_max_months,
       CASE WHEN decision_confidence_score < 0.450 THEN 'DECISION_LOW_CONFIDENCE_REVIEW'
            WHEN central_simulation_decision LIKE '%REVIEW%' OR central_simulation_decision LIKE '%LOW_CONFIDENCE%' OR stress_simulation_decision LIKE '%REVIEW%' THEN 'DECISION_WITH_SCENARIO_CAUTION'
            ELSE 'DECISION_BOARD_READY' END decision_support_status
FROM timed;





